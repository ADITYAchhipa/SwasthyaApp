/**
 * Validates structural, temporal, and hop constraints on incoming mesh packets.
 */
function validatePacket(packet) {
  if (!packet || typeof packet !== 'object') {
    return { isValid: false, reason: 'Invalid packet structure' };
  }

  // 1. Version check
  if (packet.v !== 1) {
    return { isValid: false, reason: 'Unsupported packet version' };
  }

  // 2. Required fields
  const required = ['v', 't', 'rid', 'org', 'iat', 'exp', 'ttl', 'sig'];
  for (const field of required) {
    if (packet[field] === undefined || packet[field] === null) {
      return { isValid: false, reason: `Missing required field: ${field}` };
    }
  }

  const now = Math.floor(Date.now() / 1000);

  // 3. Expiration check
  if (packet.exp <= now) {
    return { isValid: false, reason: 'Packet expired' };
  }

  // 4. Clock skew tolerance check (5 minutes / 300 seconds)
  if (Math.abs(packet.iat - now) > 300) {
    return { isValid: false, reason: 'Clock skew threshold exceeded' };
  }

  // 5. TTL limits
  if (packet.ttl < 0) {
    return { isValid: false, reason: 'Invalid TTL' };
  }

  return { isValid: true };
}

module.exports = {
  validatePacket,
};
