const express = require('express');
const router = express.Router();
const crypto = require('crypto');

const { authenticate, optionalAuth } = require('../middleware/auth');
const MeshDevice = require('../models/MeshDevice');
const OfflineMeshRequest = require('../models/OfflineMeshRequest');
const Citizen = require('../models/Citizen');
const NfcCard = require('../models/NfcCard');
const citizensRouter = require('./citizens'); // contains formatCitizen

const {
  verifyPacketSignature,
  openSealed,
  sealForDevice,
  signResponse,
  destinationToken,
  getAadBytes,
  getServerPublicKeys,
} = require('../services/meshCrypto');

const { validatePacket } = require('../services/meshValidation');

/**
 * GET /api/offline-mesh/config
 * Returns current mesh service configurations.
 */
router.get('/config', (req, res) => {
  res.json({
    enabled: process.env.OFFLINE_MESH_ENABLED === 'true',
    maxTtl: parseInt(process.env.OFFLINE_MESH_MAX_TTL || '8'),
    requestTimeoutSeconds: parseInt(process.env.OFFLINE_MESH_REQUEST_TIMEOUT_SECONDS || '120'),
    maxPacketSizeKb: parseInt(process.env.OFFLINE_MESH_MAX_PACKET_SIZE_KB || '128'),
    maxRetries: parseInt(process.env.OFFLINE_MESH_MAX_RETRIES || '3'),
  });
});

/**
 * POST /api/offline-mesh/register-device
 * Authenticates user online and binds their public keys.
 */
router.post('/register-device', authenticate, async (req, res) => {
  try {
    const { deviceId, signingPublicKey, agreementPublicKey } = req.body;
    if (!deviceId || !signingPublicKey || !agreementPublicKey) {
      return res.status(400).json({ success: false, message: 'Missing public keys or device ID' });
    }

    let device = await MeshDevice.findOne({ deviceId });
    if (device) {
      // Reject ownership rebinding if it belongs to someone else
      if (req.user.role === 'hospital' && device.hospitalId && device.hospitalId !== req.user.hospitalId) {
        return res.status(403).json({ success: false, message: 'Device owned by another hospital' });
      }
      if (req.user.role === 'citizen' && device.citizenId && device.citizenId !== req.user.citizenId) {
        return res.status(403).json({ success: false, message: 'Device owned by another citizen' });
      }

      device.signingPublicKey = signingPublicKey;
      device.agreementPublicKey = agreementPublicKey;
      device.lastSeenAt = new Date();
      await device.save();
    } else {
      const destToken = destinationToken(deviceId);
      device = new MeshDevice({
        deviceId,
        signingPublicKey,
        agreementPublicKey,
        ownerType: req.user.role,
        hospitalId: req.user.role === 'hospital' ? req.user.hospitalId : undefined,
        citizenId: req.user.role === 'citizen' ? req.user.citizenId : undefined,
        personnelId: req.user.role === 'hospital' ? req.user.personnelId : undefined,
        destinationToken: destToken,
        lastSeenAt: new Date(),
      });
      await device.save();
    }

    const serverPubs = getServerPublicKeys();
    res.json({
      success: true,
      deviceId: device.deviceId,
      destinationToken: device.destinationToken,
      serverAgreementPublicKey: serverPubs.x25519PublicB64,
      serverSigningPublicKey: serverPubs.ed25519PublicB64,
      config: {
        enabled: process.env.OFFLINE_MESH_ENABLED === 'true',
        maxTtl: parseInt(process.env.OFFLINE_MESH_MAX_TTL || '8'),
      },
    });
  } catch (err) {
    console.error('[mesh] register-device error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

/**
 * POST /api/offline-mesh/request
 * Gateway upload path. Validates and processes the packet.
 */
router.post('/request', optionalAuth, async (req, res) => {
  try {
    if (process.env.OFFLINE_MESH_ENABLED !== 'true') {
      return res.status(503).json({ success: false, code: 'MESH_DISABLED', message: 'Mesh network disabled' });
    }

    const packet = req.body;
    
    // 1. Structure/TTL validation
    const validationResult = validatePacket(packet);
    if (!validationResult.isValid) {
      return res.status(400).json({ success: false, message: validationResult.reason });
    }

    // 2. Load device
    const device = await MeshDevice.findOne({ deviceId: packet.org, status: 'active' });
    if (!device) {
      return res.status(401).json({ success: false, code: 'UNKNOWN_DEVICE', message: 'Device not enrolled or inactive' });
    }

    // 3. Signature verification
    const sigValid = verifyPacketSignature(packet, device.signingPublicKey);
    if (!sigValid) {
      return res.status(401).json({ success: false, code: 'INVALID_SIGNATURE', message: 'Packet signature invalid' });
    }

    // 4. Destination token check
    const dstBuf = Buffer.from(packet.dst);
    const expectedBuf = Buffer.from(destinationToken(device.deviceId));
    if (dstBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(dstBuf, expectedBuf)) {
      return res.status(400).json({ success: false, code: 'BAD_DESTINATION', message: 'Invalid destination token' });
    }

    // 5. Rate limiting (60 requests/device/hour)
    const oneHourAgo = new Date(Date.now() - 3600 * 1000);
    const requestCount = await OfflineMeshRequest.countDocuments({
      originDeviceId: packet.org,
      receivedAt: { $gt: oneHourAgo },
    });
    if (requestCount >= parseInt(process.env.OFFLINE_MESH_RATE_LIMIT_PER_HOUR || '60')) {
      return res.status(429).json({ success: false, message: 'Rate limit exceeded' });
    }

    // 6. Create request metadata (Replay guard)
    let meshRequest;
    try {
      meshRequest = await OfflineMeshRequest.create({
        requestId: packet.rid,
        originDeviceId: packet.org,
        createdAt: packet.iat,
        expiresAt: packet.exp,
        ttlOnArrival: packet.ttl,
        gatewayDeviceId: req.body.gatewayDeviceId || '',
        gatewayIp: req.ip || '',
        status: 'PROCESSING',
      });
    } catch (err) {
      if (err.code === 11000) {
        // Replay detected, check if response exists
        const existing = await OfflineMeshRequest.findOne({ requestId: packet.rid });
        if (existing && existing.sealedResponse) {
          return res.json({ success: true, response: JSON.parse(existing.sealedResponse) });
        }
        return res.status(409).json({ success: false, code: 'DUPLICATE_REQUEST', message: 'Duplicate request ID' });
      }
      throw err;
    }

    // 7. Open Sealed Payload
    let decryptedPayload;
    try {
      const aad = getAadBytes(packet);
      decryptedPayload = openSealed(packet.epk, packet.pay, aad, 'swasthyatap/mesh/v1/req');
    } catch (err) {
      meshRequest.status = 'REJECTED';
      meshRequest.rejectReason = 'DECRYPTION_FAILED';
      await meshRequest.save();
      return res.status(400).json({ success: false, code: 'DECRYPTION_FAILED', message: 'Payload decryption failed' });
    }

    const payloadObj = JSON.parse(decryptedPayload);
    const ref = payloadObj.ref;
    
    // Save sha256 hash of patient identifier for tracking
    meshRequest.targetRefHash = crypto.createHash('sha256').update(ref).digest('hex');

    // 8. Authorization
    if (device.ownerType === 'citizen') {
      // Citizen can only request their own profile
      if (device.citizenId !== ref) {
        meshRequest.status = 'REJECTED';
        meshRequest.rejectReason = 'UNAUTHORIZED';
        await meshRequest.save();
        return res.status(403).json({ success: false, message: 'Unauthorized' });
      }
    }

    // 9. Fetch Profile
    let citizenData = null;
    let found = false;

    if (process.env.OFFLINE_MESH_MOCK_PAYLOAD === 'true') {
      citizenData = {
        id: ref,
        fullName: 'MOCK PATIENT',
        bloodGroup: 'O+',
        chronicConditions: 'TEST_ONLY',
        allergies: 'None',
        prescriptions: [{ medicineName: 'MOCK_DATA', dosage: '1-0-1' }],
      };
      found = true;
    } else {
      let citizen = await Citizen.findOne({ profileId: ref });
      if (!citizen && ref && ref.length === 64) {
        const card = await NfcCard.findOne({ rawToken: ref });
        if (card) {
          citizen = await Citizen.findById(card.patientId);
        }
        if (!citizen) {
          const citizens = await Citizen.find({});
          citizen = citizens.find(
            c => crypto.createHash('sha256').update(c.profileId).digest('hex') === ref
          );
        }
      }

      if (citizen) {
        citizenData = citizensRouter.formatCitizen(citizen);
        found = true;
      }
    }

    // 10. Build Response Object
    const responsePayload = {
      rid: packet.rid,
      ok: found,
      citizen: citizenData,
      error: found ? undefined : 'Patient profile not found',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 120,
    };

    const responseDummyHeader = {
      v: 1,
      t: 'MEDICAL_DATA_RESPONSE',
      rid: packet.rid,
      org: packet.org,
      dst: packet.dst,
      iat: responsePayload.iat,
      exp: responsePayload.exp,
      epk: '',
    };

    const responseAad = getAadBytes(responseDummyHeader);
    const responseSealed = sealForDevice(
      responsePayload,
      device.agreementPublicKey,
      responseAad,
      'swasthyatap/mesh/v1/resp'
    );

    const responsePacket = {
      v: 1,
      t: 'MEDICAL_DATA_RESPONSE',
      rid: packet.rid,
      org: packet.org,
      dst: packet.dst,
      iat: responsePayload.iat,
      exp: responsePayload.exp,
      ttl: packet.ttl,
      epk: responseSealed.epk,
      pay: responseSealed.pay,
      sig: '',
    };

    // Sign the response packet canonical bytes
    const responseSig = signResponse(getCanonicalString(responsePacket));
    responsePacket.sig = responseSig;

    // 11. Save response and complete request metadata
    meshRequest.status = 'RESPONSE_READY';
    meshRequest.sealedResponse = JSON.stringify(responsePacket);
    meshRequest.completedAt = new Date();
    await meshRequest.save();

    res.json({ success: true, response: responsePacket });
  } catch (err) {
    console.error('[mesh] request processing error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

/**
 * GET /api/offline-mesh/response/:requestId
 * Polling fallback for gateways.
 */
router.get('/response/:requestId', async (req, res) => {
  try {
    const meshRequest = await OfflineMeshRequest.findOne({ requestId: req.params.requestId });
    if (!meshRequest) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }

    if (meshRequest.status === 'RESPONSE_READY' && meshRequest.sealedResponse) {
      return res.json({ success: true, response: JSON.parse(meshRequest.sealedResponse) });
    }

    res.status(202).json({ success: false, status: meshRequest.status, message: 'Response is not ready yet' });
  } catch (err) {
    console.error('[mesh] response-get error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

/**
 * POST /api/offline-mesh/response-ack
 * Origin device confirms delivery. Deletes the cached response.
 */
router.post('/response-ack', async (req, res) => {
  try {
    const { requestId } = req.body;
    const meshRequest = await OfflineMeshRequest.findOne({ requestId });
    if (!meshRequest) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }

    meshRequest.status = 'DELIVERED';
    meshRequest.sealedResponse = undefined; // clear ciphertext immediately
    await meshRequest.save();

    res.json({ success: true });
  } catch (err) {
    console.error('[mesh] response-ack error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

/**
 * GET /api/offline-mesh/status/:requestId
 * Returns request metadata only.
 */
router.get('/status/:requestId', async (req, res) => {
  try {
    const meshRequest = await OfflineMeshRequest.findOne({ requestId: req.params.requestId });
    if (!meshRequest) {
      return res.status(404).json({ success: false, message: 'Request not found' });
    }
    res.json({
      status: meshRequest.status,
      receivedAt: meshRequest.receivedAt,
      completedAt: meshRequest.completedAt,
    });
  } catch (err) {
    console.error('[mesh] status error:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
