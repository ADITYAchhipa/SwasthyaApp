const crypto = require('crypto');

/**
 * Helper to convert base64url to base64 for standard buffer loading.
 */
function base64urlToBase64(str) {
  let main = str.replace(/-/g, '+').replace(/_/g, '/');
  while (main.length % 4) {
    main += '=';
  }
  return main;
}

/**
 * Load Server Private Keys from environment.
 */
function getServerKeys() {
  const x25519Der = Buffer.from(process.env.MESH_SERVER_X25519_PRIVATE, 'base64');
  const ed25519Der = Buffer.from(process.env.MESH_SERVER_ED25519_PRIVATE, 'base64');

  const x25519Key = crypto.createPrivateKey({
    key: x25519Der,
    format: 'der',
    type: 'pkcs8',
  });

  const ed25519Key = crypto.createPrivateKey({
    key: ed25519Der,
    format: 'der',
    type: 'pkcs8',
  });

  return { x25519Key, ed25519Key };
}

/**
 * Verify Ed25519 signature over canonical packet string.
 */
function verifyPacketSignature(packet, signingPublicKeyB64) {
  try {
    const rawPubKey = Buffer.from(base64urlToBase64(signingPublicKeyB64), 'base64');
    const publicKeyObject = crypto.createPublicKey({
      key: {
        kty: 'OKP',
        crv: 'Ed25519',
        x: rawPubKey.toString('base64url'),
      },
      format: 'jwk',
    });

    const canonicalString = getCanonicalString(packet);
    const signature = Buffer.from(base64urlToBase64(packet.sig), 'base64');

    return crypto.verify(null, Buffer.from(canonicalString), publicKeyObject, signature);
  } catch (err) {
    return false;
  }
}

/**
 * Decrypt L2 Sealed payload.
 */
function openSealed(epkB64, ciphertextB64, aadBuffer, info) {
  const clientEpk = Buffer.from(base64urlToBase64(epkB64), 'base64');
  const sealedBytes = Buffer.from(base64urlToBase64(ciphertextB64), 'base64');

  if (sealedBytes.length < 12 + 16) {
    throw new Error('Ciphertext payload too short');
  }

  // Extract AES components
  const nonce = sealedBytes.subarray(0, 12);
  const tag = sealedBytes.subarray(sealedBytes.length - 16);
  const ciphertext = sealedBytes.subarray(12, sealedBytes.length - 16);

  const { x25519Key } = getServerKeys();

  // Load client's ephemeral public key
  const clientEpkObject = crypto.createPublicKey({
    key: {
      kty: 'OKP',
      crv: 'X25519',
      x: clientEpk.toString('base64url'),
    },
    format: 'jwk',
  });

  // ECDH Shared Secret
  const sharedSecret = crypto.diffieHellman({
    privateKey: x25519Key,
    publicKey: clientEpkObject,
  });

  // Derive Symmetric Key via HKDF-SHA256
  const derivedKey = crypto.hkdfSync(
    'sha256',
    sharedSecret,
    Buffer.alloc(0),
    Buffer.from(info),
    32
  );

  // AES-256-GCM Decrypt
  const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, nonce);
  decipher.setAAD(aadBuffer);
  decipher.setAuthTag(tag);

  let decrypted = decipher.update(ciphertext);
  decrypted = Buffer.concat([decrypted, decipher.final()]);

  return decrypted.toString('utf8');
}

/**
 * Seal L2 payload for a specific client device key.
 */
function sealForDevice(plainObj, deviceAgreementPubB64, aadBuffer, info) {
  const clientX25519Pub = Buffer.from(base64urlToBase64(deviceAgreementPubB64), 'base64');
  const cleartext = JSON.stringify(plainObj);

  // Generate ephemeral server keypair
  const { publicKey: serverEpk, privateKey: serverEpkPriv } = crypto.generateKeyPairSync('x25519');

  // Export raw public key bytes
  const epkBytes = Buffer.from(serverEpk.export({ format: 'jwk' }).x, 'base64url');

  const clientPubKeyObject = crypto.createPublicKey({
    key: {
      kty: 'OKP',
      crv: 'X25519',
      x: clientX25519Pub.toString('base64url'),
    },
    format: 'jwk',
  });

  // ECDH Shared Secret
  const sharedSecret = crypto.diffieHellman({
    privateKey: serverEpkPriv,
    publicKey: clientPubKeyObject,
  });

  // Derive Key
  const derivedKey = crypto.hkdfSync(
    'sha256',
    sharedSecret,
    Buffer.alloc(0),
    Buffer.from(info),
    32
  );

  // AES-256-GCM Encrypt
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', derivedKey, nonce);
  cipher.setAAD(aadBuffer);

  let encrypted = cipher.update(Buffer.from(cleartext, 'utf8'));
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  const tag = cipher.getAuthTag();

  // Payload = nonce (12 bytes) || ciphertext || tag (16 bytes)
  const sealedBytes = Buffer.concat([nonce, encrypted, tag]);

  return {
    epk: epkBytes.toString('base64url'),
    pay: sealedBytes.toString('base64url'),
  };
}

/**
 * Sign packet canonical string using server's Ed25519 private key.
 */
function signResponse(canonicalString) {
  const { ed25519Key } = getServerKeys();
  const signature = crypto.sign(null, Buffer.from(canonicalString), ed25519Key);
  return signature.toString('base64url');
}

/**
 * Generate stable Destination Token for deviceId using HMAC-SHA256.
 */
function destinationToken(deviceId) {
  const secret = Buffer.from(process.env.MESH_SERVER_SECRET, 'base64');
  return crypto.createHmac('sha256', secret).update(deviceId).digest('base64url');
}

/**
 * Re-create canonical JSON string representation of signature region.
 */
function getCanonicalString(packet) {
  const signKeys = ['v', 't', 'rid', 'org', 'dst', 'iat', 'exp', 'epk', 'pay'];
  if (packet.v === 2) signKeys.push('op');
  const map = {};
  for (const k of signKeys) {
    map[k] = packet[k] !== undefined ? packet[k] : '';
  }

  const sortedKeys = Object.keys(map).sort();
  let buffer = '{';
  for (let i = 0; i < sortedKeys.length; i++) {
    const key = sortedKeys[i];
    if (i > 0) buffer += ',';
    buffer += `"${key}":${JSON.stringify(map[key])}`;
  }
  buffer += '}';
  return buffer;
}

/**
 * Re-create canonical JSON string representation of AAD region.
 */
function getAadBytes(packet) {
  // The ephemeral key is generated after AAD is supplied. v2 binds that key
  // through the packet signature; both sides now use identical AAD.
  const aadKeys = ['v', 't', 'rid', 'org', 'dst', 'iat', 'exp'];
  if (packet.v === 2) aadKeys.push('op');
  else aadKeys.push('epk');
  const map = {};
  for (const k of aadKeys) {
    map[k] = packet[k] !== undefined ? packet[k] : '';
  }

  const sortedKeys = Object.keys(map).sort();
  let buffer = '{';
  for (let i = 0; i < sortedKeys.length; i++) {
    const key = sortedKeys[i];
    if (i > 0) buffer += ',';
    buffer += `"${key}":${JSON.stringify(map[key])}`;
  }
  buffer += '}';
  return Buffer.from(buffer);
}

/**
 * Retrieve Server's Public keys as base64 string.
 */
function getServerPublicKeys() {
  const { x25519Key, ed25519Key } = getServerKeys();
  const x25519PubObj = crypto.createPublicKey(x25519Key);
  const ed25519PubObj = crypto.createPublicKey(ed25519Key);
  const x25519Pub = Buffer.from(x25519PubObj.export({ format: 'jwk' }).x, 'base64url');
  const ed25519Pub = Buffer.from(ed25519PubObj.export({ format: 'jwk' }).x, 'base64url');
  return {
    x25519PublicB64: x25519Pub.toString('base64'),
    ed25519PublicB64: ed25519Pub.toString('base64'),
  };
}

module.exports = {
  verifyPacketSignature,
  openSealed,
  sealForDevice,
  signResponse,
  destinationToken,
  getCanonicalString,
  getAadBytes,
  getServerPublicKeys,
};
