const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Setup test environment
const vectorsPath = path.join(__dirname, '../../test/vectors/mesh_v2_vectors.json');
const vectors = JSON.parse(fs.readFileSync(vectorsPath, 'utf8'));

process.env.MESH_SERVER_SECRET = vectors.keys.server.secretBase64;
process.env.MESH_SERVER_X25519_PRIVATE = vectors.keys.server.x25519PrivatePkcs8Base64;
process.env.MESH_SERVER_ED25519_PRIVATE = vectors.keys.server.ed25519PrivatePkcs8Base64;

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

const { READ_HOSPITAL } = require('./services/meshValidation');
const { validEnrollment } = require('./services/meshAccess');

test('Cross-Language Cryptographic Vectors Suite (C01 - C10)', async (t) => {
  await t.test('C01: Canonical JSON and AAD strings match golden vector exactly', () => {
    const canonical = getCanonicalString({
      ...vectors.canonicalization.requestHeader,
      epk: 'test_epk_sample_value_base64url_string_43c',
      pay: 'test_pay_sample_value_base64url_string_60c',
    });
    assert.strictEqual(canonical, vectors.canonicalization.expectedCanonicalString);

    const aad = getAadBytes(vectors.canonicalization.requestHeader).toString('utf8');
    assert.strictEqual(aad, vectors.canonicalization.expectedAadString);
  });

  await t.test('C02: Server verifies and opens request golden vector', () => {
    const packet = vectors.requestVector.packet;
    const clientSigningPubB64 = vectors.keys.client.signingPublicKeyBase64;

    // Verify signature
    const sigValid = verifyPacketSignature(packet, clientSigningPubB64);
    assert.strictEqual(sigValid, true, 'Request signature must verify with client Ed25519 key');

    // Open sealed payload
    const decryptedJsonStr = openSealed(
      packet.epk,
      packet.pay,
      getAadBytes(packet),
      'swasthyatap/mesh/v2/req'
    );
    const decryptedPayload = JSON.parse(decryptedJsonStr);

    assert.deepStrictEqual(decryptedPayload, vectors.requestVector.plaintextPayload);
  });

  await t.test('C03: Client verifies and opens response golden vector', () => {
    const packet = vectors.responseVector.packet;
    const serverEdPubB64 = vectors.keys.server.ed25519PublicKeyBase64;

    // Verify server signature
    const serverEdPubKey = crypto.createPublicKey({
      key: {
        kty: 'OKP',
        crv: 'Ed25519',
        x: Buffer.from(serverEdPubB64, 'base64').toString('base64url'),
      },
      format: 'jwk',
    });
    const canonical = getCanonicalString(packet);
    const sigBytes = Buffer.from(packet.sig, 'base64url');
    const sigValid = crypto.verify(null, Buffer.from(canonical), serverEdPubKey, sigBytes);
    assert.strictEqual(sigValid, true, 'Response signature must verify with server Ed25519 key');

    // Client opens response using client agreement private key
    const clientXKey = crypto.createPrivateKey({
      key: {
        kty: 'OKP',
        crv: 'X25519',
        d: Buffer.from(vectors.keys.client.x25519SeedHex, 'hex').toString('base64url'),
        x: '',
      },
      format: 'jwk',
    });

    const serverEpkBytes = Buffer.from(packet.epk, 'base64url');
    const serverEpkObj = crypto.createPublicKey({
      key: { kty: 'OKP', crv: 'X25519', x: serverEpkBytes.toString('base64url') },
      format: 'jwk',
    });

    const sharedSecret = crypto.diffieHellman({
      privateKey: clientXKey,
      publicKey: serverEpkObj,
    });

    const derivedKey = crypto.hkdfSync(
      'sha256',
      sharedSecret,
      Buffer.alloc(0),
      Buffer.from('swasthyatap/mesh/v2/resp'),
      32
    );

    const sealedBytes = Buffer.from(packet.pay, 'base64url');
    const nonce = sealedBytes.subarray(0, 12);
    const tag = sealedBytes.subarray(sealedBytes.length - 16);
    const ciphertext = sealedBytes.subarray(12, sealedBytes.length - 16);

    const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, nonce);
    decipher.setAAD(getAadBytes(packet));
    decipher.setAuthTag(tag);

    let dec = decipher.update(ciphertext);
    dec = Buffer.concat([dec, decipher.final()]);
    const decryptedPayload = JSON.parse(dec.toString('utf8'));

    assert.deepStrictEqual(decryptedPayload, vectors.responseVector.plaintextPayload);
  });

  await t.test('C04: Gateway/relay cannot decrypt request or response with its own key', () => {
    const relayKeyPair = crypto.generateKeyPairSync('x25519');
    const packet = vectors.requestVector.packet;

    // Relay tries to decrypt request using its own private key and server ephemeral key
    const clientEpkBytes = Buffer.from(packet.epk, 'base64url');
    const clientEpkObj = crypto.createPublicKey({
      key: { kty: 'OKP', crv: 'X25519', x: clientEpkBytes.toString('base64url') },
      format: 'jwk',
    });

    const sharedSecret = crypto.diffieHellman({
      privateKey: relayKeyPair.privateKey,
      publicKey: clientEpkObj,
    });

    const derivedKey = crypto.hkdfSync(
      'sha256',
      sharedSecret,
      Buffer.alloc(0),
      Buffer.from('swasthyatap/mesh/v2/req'),
      32
    );

    const sealedBytes = Buffer.from(packet.pay, 'base64url');
    const nonce = sealedBytes.subarray(0, 12);
    const tag = sealedBytes.subarray(sealedBytes.length - 16);
    const ciphertext = sealedBytes.subarray(12, sealedBytes.length - 16);

    const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, nonce);
    decipher.setAAD(getAadBytes(packet));
    decipher.setAuthTag(tag);

    assert.throws(() => {
      decipher.update(ciphertext);
      decipher.final();
    }, /Unsupported state or unable to authenticate data/);
  });

  await t.test('C05: Modify bound fields, ephemeral key, ciphertext, or signature fails verification/decryption', () => {
    const packet = vectors.requestVector.packet;
    const clientSigningPubB64 = vectors.keys.client.signingPublicKeyBase64;

    // 1. Altered op
    const badOp = { ...packet, op: 'FETCH_CITIZEN' };
    assert.strictEqual(verifyPacketSignature(badOp, clientSigningPubB64), false);

    // 2. Altered rid
    const badRid = { ...packet, rid: crypto.randomUUID() };
    assert.strictEqual(verifyPacketSignature(badRid, clientSigningPubB64), false);

    // 3. Altered epk
    const badEpk = { ...packet, epk: 'a'.repeat(43) };
    assert.strictEqual(verifyPacketSignature(badEpk, clientSigningPubB64), false);

    // 4. Altered signature
    const badSig = { ...packet, sig: 'b'.repeat(86) };
    assert.strictEqual(verifyPacketSignature(badSig, clientSigningPubB64), false);

    // 5. Tampered ciphertext fails GCM authentication
    const tamperedCiphertext = packet.pay.slice(0, -4) + 'AAAA';
    assert.throws(() => {
      openSealed(packet.epk, tamperedCiphertext, getAadBytes(packet), 'swasthyatap/mesh/v2/req');
    });
  });

  await t.test('C06: Wrong context fails decryption (v1 context cannot decrypt v2)', () => {
    const packet = vectors.requestVector.packet;
    assert.throws(() => {
      openSealed(packet.epk, packet.pay, getAadBytes(packet), 'swasthyatap/mesh/v1/req');
    });
  });

  await t.test('C07: Repeated sealing produces fresh ciphertext and nonces', () => {
    const clientAgreePubB64 = vectors.keys.client.agreementPublicKeyBase64;
    const aad = getAadBytes(vectors.canonicalization.requestHeader);

    const sealed1 = sealForDevice({ hello: 'world' }, clientAgreePubB64, aad, 'swasthyatap/mesh/v2/resp');
    const sealed2 = sealForDevice({ hello: 'world' }, clientAgreePubB64, aad, 'swasthyatap/mesh/v2/resp');

    assert.notStrictEqual(sealed1.epk, sealed2.epk);
    assert.notStrictEqual(sealed1.pay, sealed2.pay);
  });

  await t.test('C08: Enrollment proof vector verification', () => {
    const proofVector = vectors.enrollmentProofVector;
    const body = {
      deviceId: vectors.keys.client.deviceId,
      signingPublicKey: vectors.keys.client.signingPublicKeyBase64,
      agreementPublicKey: vectors.keys.client.agreementPublicKeyBase64,
      proof: proofVector.proofSignatureBase64Url,
    };

    const isValid = validEnrollment(body, proofVector.token);
    assert.strictEqual(isValid, true, 'Golden enrollment proof must verify');

    // Proof with wrong token must fail
    assert.strictEqual(validEnrollment(body, 'wrong_token'), false);

    // Proof with altered deviceId must fail
    assert.strictEqual(validEnrollment({ ...body, deviceId: 'wrong_device_id_32_characters!' }, proofVector.token), false);
  });
});
