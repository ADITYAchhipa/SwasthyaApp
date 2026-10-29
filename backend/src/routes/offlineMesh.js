const express = require('express');
const crypto = require('crypto');
const router = express.Router();
const MeshDevice = require('../models/MeshDevice');
const OfflineMeshRequest = require('../models/OfflineMeshRequest');
const hospitals = require('./hospitals');
const citizens = require('./citizens');
const {
  verifyPacketSignature, openSealed, sealForDevice, signResponse,
  destinationToken, getAadBytes, getCanonicalString, getServerPublicKeys,
} = require('../services/meshCrypto');
const {
  validatePacket, validateReadPayload, READ_HOSPITAL, READ_PATIENT, APPROVED_OPERATIONS,
  MAX_PACKET_BYTES, MAX_LIFETIME_SECONDS, MAX_HOPS,
} = require('../services/meshValidation');
const { verifyMeshSession, ownsDevice, validateCurrentPrincipal, validEnrollment } = require('../services/meshAccess');

const enabled = () => process.env.OFFLINE_MESH_ENABLED === 'true';
const nowSeconds = () => Math.floor(Date.now() / 1000);
const deny = (res, status, code) => res.status(status).json({ success: false, code });
const audit = (requestId, op, status) => console.info('[mesh]', { requestId, operation: op, status });

router.use((req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});
router.get('/config', (req, res) => res.json({
  enabled: enabled(), protocolVersion: 2, approvedOperations: APPROVED_OPERATIONS,
  maxTtl: MAX_HOPS, requestTimeoutSeconds: MAX_LIFETIME_SECONDS,
  maxPacketSizeBytes: MAX_PACKET_BYTES, maxRetries: 3,
}));
router.use((req, res, next) => enabled() ? next() : deny(res, 503, 'MESH_DISABLED'));

async function session(req, res, next) {
  try {
    const authorization = req.get('Authorization') || '';
    if (!authorization.startsWith('Bearer ')) throw new Error();
    req.meshToken = authorization.slice(7);
    req.meshUser = verifyMeshSession(req.meshToken);
    await validateCurrentPrincipal(req.meshUser);
    next();
  } catch (_) { deny(res, 401, 'ACCESS_DENIED'); }
}

router.post('/register-device', session, async (req, res) => {
  try {
    if (!validEnrollment(req.body, req.meshToken)) return deny(res, 400, 'INVALID_ENROLLMENT');
    const { deviceId, signingPublicKey, agreementPublicKey } = req.body;
    const user = req.meshUser;
    let device = await MeshDevice.findOne({ deviceId });
    if (device) {
      // No ownership rebinding, key replacement or revoked-device resurrection.
      if (!ownsDevice(user, device) || device.status !== 'active' ||
          device.signingPublicKey !== signingPublicKey || device.agreementPublicKey !== agreementPublicKey) {
        return deny(res, 403, 'ACCESS_DENIED');
      }
    } else {
      device = await MeshDevice.create({ deviceId, signingPublicKey, agreementPublicKey,
        ownerType: user.role, hospitalId: user.hospitalId, citizenId: user.citizenId,
        personnelId: user.personnelId, destinationToken: destinationToken(deviceId), lastSeenAt: new Date() });
    }
    const keys = getServerPublicKeys();
    res.json({ success: true, deviceId, destinationToken: device.destinationToken,
      serverAgreementPublicKey: keys.x25519PublicB64, serverSigningPublicKey: keys.ed25519PublicB64,
      config: { enabled: enabled(), protocolVersion: 2 } });
  } catch (_) { deny(res, 500, 'MESH_UNAVAILABLE'); }
});

// This only revokes mesh credentials; it never changes hospital records.
router.post('/revoke-device', session, async (req, res) => {
  try {
    if (typeof req.body?.deviceId !== 'string') return deny(res, 400, 'INVALID_DEVICE');
    const device = await MeshDevice.findOne({ deviceId: req.body.deviceId });
    if (!device || !ownsDevice(req.meshUser, device)) return deny(res, 403, 'ACCESS_DENIED');
    device.status = 'revoked';
    await device.save();
    await OfflineMeshRequest.updateMany({ originDeviceId: device.deviceId }, { $unset: { sealedResponse: 1 } });
    res.json({ success: true });
  } catch (_) { deny(res, 500, 'MESH_UNAVAILABLE'); }
});

function responsePacket(packet, device, payload, exp = packet.exp, op = packet.op) {
  const iat = nowSeconds();
  if (iat >= exp) return null;
  const header = { v: 2, t: 'MEDICAL_DATA_RESPONSE', op,
    rid: packet.rid, org: packet.org, dst: packet.dst, iat, exp, ttl: MAX_HOPS };
  const sealed = sealForDevice({ ...payload, rid: packet.rid, op, iat, exp },
    device.agreementPublicKey, getAadBytes(header), 'swasthyatap/mesh/v2/resp');
  const response = { ...header, ...sealed };
  response.sig = signResponse(getCanonicalString(response));
  return Buffer.byteLength(JSON.stringify(response)) <= MAX_PACKET_BYTES ? response : null;
}

// Gateway is a ciphertext transport. Its bearer token confers no origin rights.
router.post('/request', async (req, res) => {
  try {
    const packet = req.body;
    if (!validatePacket(packet).isValid) return deny(res, 400, 'INVALID_PACKET');
    const device = await MeshDevice.findOne({ deviceId: packet.org, status: 'active' });
    if (!device || !verifyPacketSignature(packet, device.signingPublicKey)) return deny(res, 401, 'ACCESS_DENIED');
    const expected = destinationToken(device.deviceId);
    if (expected.length !== packet.dst.length || !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(packet.dst))) {
      return deny(res, 401, 'ACCESS_DENIED');
    }
    const sealedDenial = () => {
      const response = responsePacket(packet, device, { ok: false, code: 'ACCESS_DENIED' }, packet.exp, packet.op);
      return response ? res.json({ success: true, response }) : deny(res, 410, 'REQUEST_EXPIRED');
    };
    let payload, user;
    try {
      payload = JSON.parse(openSealed(packet.epk, packet.pay, getAadBytes(packet), 'swasthyatap/mesh/v2/req'));
      if (!validateReadPayload(payload, packet)) return sealedDenial();
      user = verifyMeshSession(payload.token);
      if (!ownsDevice(user, device)) return sealedDenial();
      await validateCurrentPrincipal(user); // checked at processing time, including retries
    } catch (_) { return sealedDenial(); }

    const digest = crypto.createHash('sha256').update(getCanonicalString(packet)).digest('hex');
    const replay = async () => {
      const existing = await OfflineMeshRequest.findOne({ requestId: packet.rid });
      if (!existing || existing.originDeviceId !== packet.org || existing.requestDigest !== digest) {
        return deny(res, 409, 'DUPLICATE_REQUEST');
      }
      if (existing.expiresAt <= nowSeconds()) return deny(res, 410, 'REQUEST_EXPIRED');
      if (existing.sealedResponse) {
        if (!enabled()) return deny(res, 503, 'MESH_DISABLED');
        const activeDevice = await MeshDevice.findOne({ deviceId: packet.org, status: 'active' });
        if (!activeDevice) return sealedDenial();
        const response = JSON.parse(existing.sealedResponse);
        if (response.exp <= nowSeconds()) return deny(res, 410, 'REQUEST_EXPIRED');
        return res.json({ success: true, response });
      }
      return deny(res, 409, 'REQUEST_PENDING');
    };
    if (await OfflineMeshRequest.findOne({ requestId: packet.rid })) return replay();
    const count = await OfflineMeshRequest.countDocuments({ originDeviceId: packet.org,
      receivedAt: { $gt: new Date(Date.now() - 15 * 60 * 1000) } });
    if (count >= 60) return deny(res, 429, 'RATE_LIMITED');

    let record;
    try {
      record = await OfflineMeshRequest.create({ requestId: packet.rid, originDeviceId: packet.org,
        requestType: packet.op, requestDigest: digest, createdAt: packet.iat,
        expiresAt: packet.exp, ttlOnArrival: packet.ttl, status: 'PROCESSING', authorizedAt: new Date(),
        // Keyed target correlation prevents guessing identifiers from a DB dump.
        targetRefHash: crypto.createHmac('sha256', Buffer.from(process.env.MESH_SERVER_SECRET, 'base64'))
          .update(payload.ref).digest('hex') });
    } catch (err) {
      if (err.code === 11000) return replay();
      throw err;
    }

    let resultData = null;
    let isFound = false;

    if (packet.op === READ_HOSPITAL) {
      const hospital = await hospitals.readHospital(payload.ref);
      record.snapshotAt = new Date();
      isFound = !!hospital;
      audit(packet.rid, packet.op, isFound ? 'READ_COMPLETED' : 'READ_NOT_FOUND');
      resultData = { hospital: hospital || undefined };
    } else if (packet.op === READ_PATIENT) {
      // Role-Based Access Control: Only an authorized doctor may query patient records over mesh
      if (user.role !== 'hospital' || user.hospitalRole !== 'doctor') {
        record.status = 'REJECTED';
        await record.save();
        audit(packet.rid, packet.op, 'ACCESS_DENIED_NOT_DOCTOR');
        return sealedDenial();
      }

      const patient = await citizens.readPatientForDoctor(payload.ref);
      record.snapshotAt = new Date();
      isFound = !!patient;
      audit(packet.rid, packet.op, isFound ? 'READ_COMPLETED' : 'READ_NOT_FOUND');
      resultData = { patient: patient || undefined };
    }

    // Recheck access after the read, before releasing ciphertext.
    try {
      verifyMeshSession(payload.token);
      await validateCurrentPrincipal(user);
      if (!await MeshDevice.findOne({ deviceId: packet.org, status: 'active' })) throw new Error();
    } catch (_) {
      record.status = 'REJECTED';
      await record.save();
      return sealedDenial();
    }
    if (!enabled()) return deny(res, 503, 'MESH_DISABLED');
    const response = responsePacket(packet, device, {
      ok: isFound,
      ...resultData,
      code: isFound ? undefined : 'NOT_FOUND',
      receivedAt: record.receivedAt, authorizedAt: record.authorizedAt,
      snapshotAt: record.snapshotAt,
    }, Math.min(packet.exp, user.exp), packet.op);
    if (!response) {
      record.status = 'EXPIRED';
      await record.save();
      return deny(res, 410, 'RESPONSE_UNAVAILABLE');
    }
    record.status = 'RESPONSE_READY';
    record.sealedResponse = JSON.stringify(response);
    record.completedAt = new Date();
    await record.save();
    return res.json({ success: true, response });
  } catch (_) { return deny(res, 500, 'MESH_UNAVAILABLE'); }
});

// Legacy unauthenticated polling/ack/status exposed activity and allowed response
// deletion. Retry the original signed, sealed request instead (reauthorizes it).
router.all(['/response/:requestId', '/response-ack', '/status/:requestId'], (req, res) => deny(res, 410, 'UNSUPPORTED_OPERATION'));
module.exports = router;

// Legacy unauthenticated polling/ack/status exposed activity and allowed response
// deletion. Retry the original signed, sealed request instead (reauthorizes it).
router.all(['/response/:requestId', '/response-ack', '/status/:requestId'], (req, res) => deny(res, 410, 'UNSUPPORTED_OPERATION'));
module.exports = router;
