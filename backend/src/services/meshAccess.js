const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const Hospital = require('../models/Hospital');
const Citizen = require('../models/Citizen');

// Reuse the existing JWT issuer, secret and principal records. The online demo
// token exceptions are deliberately ineligible for mesh enrollment or reads.
function verifyMeshSession(token) {
  const user = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
  if (!Number.isSafeInteger(user.exp)) throw new Error('ACCESS_DENIED');
  if (typeof user.hospitalId === 'string' && typeof user.personnelId === 'string' && !user.citizenId) {
    return {
      ...user,
      hospitalRole: user.role || 'doctor',
      role: 'hospital',
    };
  }
  if (typeof user.citizenId === 'string' && !user.hospitalId) return { ...user, role: 'citizen' };
  throw new Error('ACCESS_DENIED');
}

function ownsDevice(user, device) {
  return user.role === device.ownerType && (user.role === 'hospital'
    ? user.hospitalId === device.hospitalId && user.personnelId === device.personnelId
    : user.citizenId === device.citizenId);
}

async function validateCurrentPrincipal(user) {
  if (user.role === 'hospital') {
    const exists = await Hospital.exists({
      hospitalId: user.hospitalId,
      isVerified: true,
      'authorizedPersonnel.personnelId': user.personnelId,
    });
    if (!exists) throw new Error('ACCESS_DENIED');
    if (typeof Hospital.findOne === 'function') {
      try {
        const hospital = await Hospital.findOne({ hospitalId: user.hospitalId, isVerified: true });
        const personnel = hospital?.authorizedPersonnel?.find(p => p.personnelId === user.personnelId);
        if (personnel && personnel.role) {
          user.hospitalRole = personnel.role;
        }
      } catch (_) {}
    }
  } else {
    const exists = await Citizen.exists({ profileId: user.citizenId });
    if (!exists) throw new Error('ACCESS_DENIED');
  }
}

function enrollmentBytes(body, token) {
  return Buffer.from(JSON.stringify([2, 'REGISTER_DEVICE', body.deviceId, body.signingPublicKey,
    body.agreementPublicKey, crypto.createHash('sha256').update(token).digest('hex')]));
}

function validEnrollment(body, token) {
  if (!body || Object.keys(body).sort().join(',') !== 'agreementPublicKey,deviceId,proof,signingPublicKey') return false;
  try {
    for (const key of ['signingPublicKey', 'agreementPublicKey']) {
      if (typeof body[key] !== 'string' || !/^[A-Za-z0-9+/]{43}=$/.test(body[key])) return false;
    }
    const signing = Buffer.from(body.signingPublicKey, 'base64');
    if (crypto.createHash('sha256').update(signing).digest('base64url').slice(0, 32) !== body.deviceId) return false;
    const key = crypto.createPublicKey({ key: { kty: 'OKP', crv: 'Ed25519', x: signing.toString('base64url') }, format: 'jwk' });
    return typeof body.proof === 'string' && /^[A-Za-z0-9_-]{86}$/.test(body.proof) &&
      crypto.verify(null, enrollmentBytes(body, token), key, Buffer.from(body.proof, 'base64url'));
  } catch (_) { return false; }
}

module.exports = { verifyMeshSession, ownsDevice, validateCurrentPrincipal, enrollmentBytes, validEnrollment };
