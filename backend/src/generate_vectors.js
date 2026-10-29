const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Fixed test environment keys
const serverSecret = 'by4sxUhzzdTfLvFzJ4I5qrvO3c8InzMbhK5Dhi9MLQU=';
const serverX25519PrivPkcs8 = 'MC4CAQAwBQYDK2VuBCIEIOBjfC/qGh63EPx2FHizgINtGS/1jgry7eFcNCKO3rlK';
const serverEd25519PrivPkcs8 = 'MC4CAQAwBQYDK2VwBCIEIA7PrPE7RO77QBmnmK/blej3I9X2JJpx/hSat421wspE';

process.env.MESH_SERVER_SECRET = serverSecret;
process.env.MESH_SERVER_X25519_PRIVATE = serverX25519PrivPkcs8;
process.env.MESH_SERVER_ED25519_PRIVATE = serverEd25519PrivPkcs8;

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

const {
  READ_HOSPITAL,
  MAX_PACKET_BYTES,
  MAX_LIFETIME_SECONDS,
  MAX_HOPS,
} = require('./services/meshValidation');

const { enrollmentBytes } = require('./services/meshAccess');

// 1. Client Keys (deterministic 32-byte seeds)
const clientEdSeed = Buffer.alloc(32, 0x01);
const clientXSeed = Buffer.alloc(32, 0x02);
const clientEpkSeed = Buffer.alloc(32, 0x03);
const serverEpkSeed = Buffer.alloc(32, 0x04);

const clientEdKey = crypto.createPrivateKey({
  key: { kty: 'OKP', crv: 'Ed25519', d: clientEdSeed.toString('base64url'), x: '' },
  format: 'jwk',
});
const clientXKey = crypto.createPrivateKey({
  key: { kty: 'OKP', crv: 'X25519', d: clientXSeed.toString('base64url'), x: '' },
  format: 'jwk',
});

const clientEdPubObj = crypto.createPublicKey(clientEdKey);
const clientXPubObj = crypto.createPublicKey(clientXKey);

const clientSigningPubKeyRaw = Buffer.from(clientEdPubObj.export({ format: 'jwk' }).x, 'base64url');
const clientAgreementPubKeyRaw = Buffer.from(clientXPubObj.export({ format: 'jwk' }).x, 'base64url');

const clientSigningPublicKey = clientSigningPubKeyRaw.toString('base64');
const clientAgreementPublicKey = clientAgreementPubKeyRaw.toString('base64');

const clientDeviceId = crypto.createHash('sha256').update(clientSigningPubKeyRaw).digest('base64url').slice(0, 32);
const destToken = destinationToken(clientDeviceId);

const serverPubs = getServerPublicKeys();
const serverX25519Pub = Buffer.from(serverPubs.x25519PublicB64, 'base64');
const serverEd25519Pub = Buffer.from(serverPubs.ed25519PublicB64, 'base64');

// 2. Canonical serialization vectors
const sampleRequestHeader = {
  v: 2,
  t: 'MEDICAL_DATA_REQUEST',
  op: READ_HOSPITAL,
  rid: '550e8400-e29b-41d4-a716-446655440000',
  org: clientDeviceId,
  dst: destToken,
  iat: 1700000000,
  exp: 1700000120,
  ttl: 5,
};

const sampleRequestCanonical = getCanonicalString({
  ...sampleRequestHeader,
  epk: 'test_epk_sample_value_base64url_string_43c',
  pay: 'test_pay_sample_value_base64url_string_60c',
});

const sampleRequestAad = getAadBytes(sampleRequestHeader).toString('utf8');

// 3. Sealed Request Vector (Client -> Server)
const clientEpkKey = crypto.createPrivateKey({
  key: { kty: 'OKP', crv: 'X25519', d: clientEpkSeed.toString('base64url'), x: '' },
  format: 'jwk',
});
const clientEpkPubRaw = Buffer.from(crypto.createPublicKey(clientEpkKey).export({ format: 'jwk' }).x, 'base64url');

const serverPubKeyObj = crypto.createPublicKey({
  key: { kty: 'OKP', crv: 'X25519', x: serverX25519Pub.toString('base64url') },
  format: 'jwk',
});

const clientSharedSecret = crypto.diffieHellman({
  privateKey: clientEpkKey,
  publicKey: serverPubKeyObj,
});

const clientDerivedKey = crypto.hkdfSync('sha256', clientSharedSecret, Buffer.alloc(0), Buffer.from('swasthyatap/mesh/v2/req'), 32);
const deterministicReqNonce = Buffer.from([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
const reqCipher = crypto.createCipheriv('aes-256-gcm', clientDerivedKey, deterministicReqNonce);
reqCipher.setAAD(getAadBytes(sampleRequestHeader));

const reqPlaintextObj = {
  op: READ_HOSPITAL,
  ref: 'HOSP_GOLDEN_1',
  token: 'origin_jwt_token_sample_string_for_testing_123',
};
const reqPlaintext = JSON.stringify(reqPlaintextObj);
let encReq = reqCipher.update(Buffer.from(reqPlaintext, 'utf8'));
encReq = Buffer.concat([encReq, reqCipher.final()]);
const reqTag = reqCipher.getAuthTag();
const reqSealedBytes = Buffer.concat([deterministicReqNonce, encReq, reqTag]);

const requestPacket = {
  ...sampleRequestHeader,
  epk: clientEpkPubRaw.toString('base64url'),
  pay: reqSealedBytes.toString('base64url'),
};
const reqCanonicalStr = getCanonicalString(requestPacket);
const reqSignature = crypto.sign(null, Buffer.from(reqCanonicalStr), clientEdKey);
requestPacket.sig = reqSignature.toString('base64url');

// 4. Sealed Response Vector (Server -> Client)
const serverEpkKey = crypto.createPrivateKey({
  key: { kty: 'OKP', crv: 'X25519', d: serverEpkSeed.toString('base64url'), x: '' },
  format: 'jwk',
});
const serverEpkPubRaw = Buffer.from(crypto.createPublicKey(serverEpkKey).export({ format: 'jwk' }).x, 'base64url');

const clientAgreementPubObj = crypto.createPublicKey({
  key: { kty: 'OKP', crv: 'X25519', x: clientAgreementPubKeyRaw.toString('base64url') },
  format: 'jwk',
});

const serverSharedSecret = crypto.diffieHellman({
  privateKey: serverEpkKey,
  publicKey: clientAgreementPubObj,
});

const serverDerivedKey = crypto.hkdfSync('sha256', serverSharedSecret, Buffer.alloc(0), Buffer.from('swasthyatap/mesh/v2/resp'), 32);
const deterministicRespNonce = Buffer.from([12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);

const sampleResponseHeader = {
  v: 2,
  t: 'MEDICAL_DATA_RESPONSE',
  op: READ_HOSPITAL,
  rid: sampleRequestHeader.rid,
  org: sampleRequestHeader.org,
  dst: sampleRequestHeader.dst,
  iat: 1700000005,
  exp: 1700000120,
  ttl: 8,
};

const respCipher = crypto.createCipheriv('aes-256-gcm', serverDerivedKey, deterministicRespNonce);
respCipher.setAAD(getAadBytes(sampleResponseHeader));

const respPlaintextObj = {
  ok: true,
  hospital: {
    hospitalId: 'HOSP_GOLDEN_1',
    name: 'National Golden Hospital',
    city: 'Bangalore',
    phone: '+91 80 1234 5678',
  },
  receivedAt: '2026-10-24T10:00:00.000Z',
  authorizedAt: '2026-10-24T10:00:01.000Z',
  snapshotAt: '2026-10-24T10:00:02.000Z',
  dataUpdatedAt: '2026-10-24T09:00:00.000Z',
  rid: sampleRequestHeader.rid,
  op: READ_HOSPITAL,
  iat: sampleResponseHeader.iat,
  exp: sampleResponseHeader.exp,
};
const respPlaintext = JSON.stringify(respPlaintextObj);
let encResp = respCipher.update(Buffer.from(respPlaintext, 'utf8'));
encResp = Buffer.concat([encResp, respCipher.final()]);
const respTag = respCipher.getAuthTag();
const respSealedBytes = Buffer.concat([deterministicRespNonce, encResp, respTag]);

const responsePacket = {
  ...sampleResponseHeader,
  epk: serverEpkPubRaw.toString('base64url'),
  pay: respSealedBytes.toString('base64url'),
};
const respCanonicalStr = getCanonicalString(responsePacket);
responsePacket.sig = signResponse(respCanonicalStr);

// 5. Enrollment Proof Vector (Dart -> Node)
const sampleToken = 'enrollment_jwt_token_for_verification_test';
const proofBytes = enrollmentBytes(
  {
    deviceId: clientDeviceId,
    signingPublicKey: clientSigningPublicKey,
    agreementPublicKey: clientAgreementPublicKey,
  },
  sampleToken
);
const proofSignature = crypto.sign(null, proofBytes, clientEdKey).toString('base64url');

const goldenVectors = {
  metadata: {
    protocolVersion: 2,
    generatedAt: '2026-10-24T15:30:00Z',
    description: 'Offline Mesh v2 Cross-Language Cryptographic Golden Vectors',
  },
  keys: {
    server: {
      secretBase64: serverSecret,
      x25519PrivatePkcs8Base64: serverX25519PrivPkcs8,
      x25519PublicKeyBase64: serverPubs.x25519PublicB64,
      ed25519PrivatePkcs8Base64: serverEd25519PrivPkcs8,
      ed25519PublicKeyBase64: serverPubs.ed25519PublicB64,
    },
    client: {
      ed25519SeedHex: clientEdSeed.toString('hex'),
      x25519SeedHex: clientXSeed.toString('hex'),
      signingPublicKeyBase64: clientSigningPublicKey,
      agreementPublicKeyBase64: clientAgreementPublicKey,
      deviceId: clientDeviceId,
      destinationToken: destToken,
    },
  },
  canonicalization: {
    requestHeader: sampleRequestHeader,
    expectedCanonicalString: sampleRequestCanonical,
    expectedAadString: sampleRequestAad,
  },
  requestVector: {
    plaintextPayload: reqPlaintextObj,
    packet: requestPacket,
  },
  responseVector: {
    plaintextPayload: respPlaintextObj,
    packet: responsePacket,
  },
  enrollmentProofVector: {
    token: sampleToken,
    proofBytesUtf8: proofBytes.toString('utf8'),
    proofSignatureBase64Url: proofSignature,
  },
};

const outDir = path.join(__dirname, '../../test/vectors');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'mesh_v2_vectors.json'), JSON.stringify(goldenVectors, null, 2), 'utf8');
console.log('✅ Generated mesh_v2_vectors.json successfully.');
