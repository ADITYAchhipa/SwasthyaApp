// Closed protocol: adding an operation requires a server policy and tests.
const READ_HOSPITAL = 'READ_HOSPITAL';
const READ_PATIENT = 'READ_PATIENT';
const APPROVED_OPERATIONS = [READ_HOSPITAL, READ_PATIENT];

const MAX_PACKET_BYTES = 96 * 1024; // below the existing Express JSON limit
const MAX_LIFETIME_SECONDS = 120;
const MAX_HOPS = 8;
const fields = ['v', 't', 'op', 'rid', 'org', 'dst', 'iat', 'exp', 'ttl', 'epk', 'pay', 'sig'];
const b64url = /^[A-Za-z0-9_-]+$/;

function validatePacket(packet, now = Math.floor(Date.now() / 1000)) {
  const reject = () => ({ isValid: false, reason: 'INVALID_PACKET' });
  if (!packet || Array.isArray(packet) || typeof packet !== 'object') return reject();
  if (Object.keys(packet).length !== fields.length || fields.some(k => !(k in packet))) return reject();
  if (Buffer.byteLength(JSON.stringify(packet)) > MAX_PACKET_BYTES) return reject();
  if (packet.v !== 2 || packet.t !== 'MEDICAL_DATA_REQUEST' || !APPROVED_OPERATIONS.includes(packet.op)) return reject();
  if (typeof packet.rid !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(packet.rid)) return reject();
  for (const key of ['org', 'dst', 'epk', 'pay', 'sig']) {
    if (typeof packet[key] !== 'string' || !b64url.test(packet[key])) return reject();
  }
  if (packet.org.length !== 32 || packet.dst.length !== 43 || packet.epk.length !== 43 || packet.sig.length !== 86) return reject();
  if (Buffer.from(packet.pay, 'base64url').length < 28) return reject();
  if (![packet.iat, packet.exp, packet.ttl].every(Number.isSafeInteger)) return reject();
  if (packet.iat > now + 30 || packet.exp <= now || packet.exp <= packet.iat || packet.exp - packet.iat > MAX_LIFETIME_SECONDS) return reject();
  if (packet.ttl < 0 || packet.ttl > MAX_HOPS) return reject();
  return { isValid: true };
}

function validateReadPayload(payload, packet) {
  return !!payload && typeof payload === 'object' && !Array.isArray(payload) &&
    Object.keys(payload).sort().join(',') === 'op,ref,token' &&
    APPROVED_OPERATIONS.includes(payload.op) && payload.op === packet.op &&
    typeof payload.ref === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(payload.ref) &&
    typeof payload.token === 'string' && payload.token.length > 0 && payload.token.length <= 8192;
}

module.exports = {
  validatePacket,
  validateReadPayload,
  READ_HOSPITAL,
  READ_PATIENT,
  APPROVED_OPERATIONS,
  MAX_PACKET_BYTES,
  MAX_LIFETIME_SECONDS,
  MAX_HOPS,
};
