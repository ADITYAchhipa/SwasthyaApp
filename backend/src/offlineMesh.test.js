const test = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');

// Set test environment variables before requiring the service
process.env.MESH_SERVER_SECRET = 'by4sxUhzzdTfLvFzJ4I5qrvO3c8InzMbhK5Dhi9MLQU=';
process.env.MESH_SERVER_X25519_PRIVATE = 'MC4CAQAwBQYDK2VuBCIEIOBjfC/qGh63EPx2FHizgINtGS/1jgry7eFcNCKO3rlK';
process.env.MESH_SERVER_ED25519_PRIVATE = 'MC4CAQAwBQYDK2VwBCIEIA7PrPE7RO77QBmnmK/blej3I9X2JJpx/hSat421wspE';

const {
  verifyPacketSignature,
  openSealed,
  sealForDevice,
  signResponse,
  destinationToken,
  getCanonicalString,
  getAadBytes,
  getServerPublicKeys,
} = require('./services/meshCrypto');

const { validatePacket } = require('./services/meshValidation');

test('Offline Mesh Cryptography & Validation', async (t) => {
  
  await t.test('destinationToken generation is stable', () => {
    const deviceId = 'test_device_id_1234567890';
    const token1 = destinationToken(deviceId);
    const token2 = destinationToken(deviceId);
    assert.strictEqual(token1, token2);
    assert.match(token1, /^[A-Za-z0-9_-]+$/); // base64url format
  });

  await t.test('validatePacket structural checks', () => {
    const validPacket = {
      v: 1,
      t: 'MEDICAL_DATA_REQUEST',
      rid: 'uuid-1234-5678',
      org: 'device_id_hash',
      dst: 'dest_token',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 60,
      ttl: 5,
      sig: 'sig_bytes',
    };

    const res = validatePacket(validPacket);
    assert.strictEqual(res.isValid, true);

    const expired = { ...validPacket, exp: Math.floor(Date.now() / 1000) - 10 };
    assert.strictEqual(validatePacket(expired).isValid, false);

    const versionMismatch = { ...validPacket, v: 2 };
    assert.strictEqual(validatePacket(versionMismatch).isValid, false);

    const badSkew = { ...validPacket, iat: Math.floor(Date.now() / 1000) - 400 };
    assert.strictEqual(validatePacket(badSkew).isValid, false);
  });

  await t.test('getServerPublicKeys derives correct formats', () => {
    const pubs = getServerPublicKeys();
    assert.ok(pubs.x25519PublicB64);
    assert.ok(pubs.ed25519PublicB64);
    // Keys should be base64 encoded
    assert.doesNotThrow(() => Buffer.from(pubs.x25519PublicB64, 'base64'));
    assert.doesNotThrow(() => Buffer.from(pubs.ed25519PublicB64, 'base64'));
  });

  await t.test('L2 Seal and Open roundtrip', () => {
    const pubs = getServerPublicKeys();
    const clientX25519 = crypto.generateKeyPairSync('x25519');
    const clientX25519PubB64 = Buffer.from(clientX25519.publicKey.export({ format: 'jwk' }).x, 'base64url').toString('base64');

    const cleartext = JSON.stringify({ secret: 'patient-42', blood: 'O-' });
    const dummyPacket = {
      v: 1,
      t: 'MEDICAL_DATA_RESPONSE',
      rid: 'req-42',
      org: 'org-hash',
      dst: 'dst-token',
      iat: 1234567,
      exp: 1234687,
      epk: '',
    };
    const aad = getAadBytes(dummyPacket);

    // Server seals response for client
    const sealed = sealForDevice(
      { ok: true, data: cleartext },
      clientX25519PubB64,
      aad,
      'swasthyatap/mesh/v1/resp'
    );

    assert.ok(sealed.epk);
    assert.ok(sealed.pay);

    // Client opens response using client private key
    const clientPrivateDer = clientX25519.privateKey.export({ type: 'pkcs8', format: 'der' });
    const clientPrivateKeyObject = crypto.createPrivateKey({
      key: clientPrivateDer,
      format: 'der',
      type: 'pkcs8',
    });

    // Custom L2 open for testing client-side open
    const clientEpk = Buffer.from(sealed.epk, 'base64url');
    const sealedBytes = Buffer.from(sealed.pay, 'base64url');

    const nonce = sealedBytes.subarray(0, 12);
    const tag = sealedBytes.subarray(sealedBytes.length - 16);
    const ciphertext = sealedBytes.subarray(12, sealedBytes.length - 16);

    const clientEpkObject = crypto.createPublicKey({
      key: {
        kty: 'OKP',
        crv: 'X25519',
        x: clientEpk.toString('base64url'),
      },
      format: 'jwk',
    });

    const sharedSecret = crypto.diffieHellman({
      privateKey: clientPrivateKeyObject,
      publicKey: clientEpkObject,
    });

    const derivedKey = crypto.hkdfSync(
      'sha256',
      sharedSecret,
      Buffer.alloc(0),
      Buffer.from('swasthyatap/mesh/v1/resp'),
      32
    );

    const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, nonce);
    decipher.setAAD(aad);
    decipher.setAuthTag(tag);

    let decrypted = decipher.update(ciphertext);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    const result = JSON.parse(decrypted.toString('utf8'));
    assert.strictEqual(result.ok, true);
    assert.strictEqual(result.data, cleartext);
  });
});
