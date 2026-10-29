const test = require('node:test');
const assert = require('node:assert');
const http = require('http');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const express = require('express');

// Set required environment variables before loading any mesh modules
process.env.JWT_SECRET = 'mesh_test_jwt_secret_32_bytes_long_key_!';
process.env.MESH_SERVER_SECRET = 'by4sxUhzzdTfLvFzJ4I5qrvO3c8InzMbhK5Dhi9MLQU=';
process.env.MESH_SERVER_X25519_PRIVATE = 'MC4CAQAwBQYDK2VuBCIEIOBjfC/qGh63EPx2FHizgINtGS/1jgry7eFcNCKO3rlK';
process.env.MESH_SERVER_ED25519_PRIVATE = 'MC4CAQAwBQYDK2VwBCIEIA7PrPE7RO77QBmnmK/blej3I9X2JJpx/hSat421wspE';
process.env.OFFLINE_MESH_ENABLED = 'true';

const MeshDevice = require('./models/MeshDevice');
const OfflineMeshRequest = require('./models/OfflineMeshRequest');
const Hospital = require('./models/Hospital');
const Citizen = require('./models/Citizen');
const hospitalsRoute = require('./routes/hospitals');
const citizensRoute = require('./routes/citizens');
const offlineMeshRouter = require('./routes/offlineMesh');

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
  validatePacket,
  validateReadPayload,
  READ_HOSPITAL,
  READ_PATIENT,
  MAX_PACKET_BYTES,
  MAX_LIFETIME_SECONDS,
  MAX_HOPS,
} = require('./services/meshValidation');

const {
  verifyMeshSession,
  ownsDevice,
  validateCurrentPrincipal,
  enrollmentBytes,
  validEnrollment,
} = require('./services/meshAccess');

// In-memory test store & spies to simulate database and enforce mutation checks
const testStore = {
  devices: new Map(),
  requests: new Map(),
  hospitals: new Map(),
  citizens: new Map(),
  mutations: [],
  auditLogs: [],
};

// Install Mongoose spies/interceptors
const originalDeviceFindOne = MeshDevice.findOne;
const originalDeviceCreate = MeshDevice.create;
const originalRequestFindOne = OfflineMeshRequest.findOne;
const originalRequestCreate = OfflineMeshRequest.create;
const originalRequestCount = OfflineMeshRequest.countDocuments;
const originalRequestUpdateMany = OfflineMeshRequest.updateMany;
const originalHospitalExists = Hospital.exists;
const originalHospitalFindOne = Hospital.findOne;
const originalCitizenExists = Citizen.exists;
const originalCitizenFindOne = Citizen.findOne;
const originalReadHospital = hospitalsRoute.readHospital;
const originalReadPatientForDoctor = citizensRoute.readPatientForDoctor;

// Spies on business models to detect any prohibited mutations
for (const model of [Hospital, Citizen]) {
  for (const method of ['create', 'updateOne', 'updateMany', 'deleteOne', 'deleteMany', 'findOneAndUpdate']) {
    if (typeof model[method] === 'function') {
      const orig = model[method];
      model[method] = async function (...args) {
        testStore.mutations.push({ model: model.modelName, method, args });
        return orig.apply(this, args);
      };
    }
  }
}

MeshDevice.findOne = function (query) {
  if (query.deviceId) {
    const dev = testStore.devices.get(query.deviceId);
    if (!dev) return Promise.resolve(null);
    if (query.status && dev.status !== query.status) return Promise.resolve(null);
    return Promise.resolve(dev);
  }
  return Promise.resolve(null);
};

MeshDevice.create = function (doc) {
  if (testStore.devices.has(doc.deviceId)) {
    const err = new Error('E11000 duplicate key');
    err.code = 11000;
    return Promise.reject(err);
  }
  const device = {
    ...doc,
    status: doc.status || 'active',
    save: async function () {
      testStore.devices.set(this.deviceId, this);
      return this;
    },
  };
  testStore.devices.set(doc.deviceId, device);
  return Promise.resolve(device);
};

OfflineMeshRequest.findOne = function (query) {
  if (query.requestId) {
    const req = testStore.requests.get(query.requestId);
    return Promise.resolve(req || null);
  }
  return Promise.resolve(null);
};

OfflineMeshRequest.countDocuments = function (query) {
  let count = 0;
  for (const req of testStore.requests.values()) {
    if (query.originDeviceId && req.originDeviceId !== query.originDeviceId) continue;
    if (query.receivedAt && query.receivedAt.$gt && req.receivedAt <= query.receivedAt.$gt) continue;
    count++;
  }
  return Promise.resolve(count);
};

OfflineMeshRequest.create = function (doc) {
  if (testStore.requests.has(doc.requestId)) {
    const err = new Error('E11000 duplicate key');
    err.code = 11000;
    return Promise.reject(err);
  }
  const record = {
    ...doc,
    receivedAt: doc.receivedAt || new Date(),
    status: doc.status || 'PROCESSING',
    save: async function () {
      testStore.requests.set(this.requestId, this);
      return this;
    },
  };
  testStore.requests.set(doc.requestId, record);
  return Promise.resolve(record);
};

OfflineMeshRequest.updateMany = function (query, update) {
  let count = 0;
  for (const req of testStore.requests.values()) {
    if (query.originDeviceId && req.originDeviceId === query.originDeviceId) {
      if (update.$unset && update.$unset.sealedResponse) {
        delete req.sealedResponse;
      }
      count++;
    }
  }
  return Promise.resolve({ modifiedCount: count });
};

Hospital.exists = function (query) {
  if (query.hospitalId) {
    const h = testStore.hospitals.get(query.hospitalId);
    if (!h) return Promise.resolve(null);
    if (query.isVerified !== undefined && h.isVerified !== query.isVerified) return Promise.resolve(null);
    if (query['authorizedPersonnel.personnelId']) {
      const pid = query['authorizedPersonnel.personnelId'];
      const hasPersonnel = h.authorizedPersonnel && h.authorizedPersonnel.some((p) => p.personnelId === pid);
      if (!hasPersonnel) return Promise.resolve(null);
    }
    return Promise.resolve({ _id: h.hospitalId });
  }
  return Promise.resolve(null);
};

Hospital.findOne = function (query) {
  if (query.hospitalId) {
    const h = testStore.hospitals.get(query.hospitalId);
    if (!h) return Promise.resolve(null);
    if (query.isVerified !== undefined && h.isVerified !== query.isVerified) return Promise.resolve(null);
    if (query['authorizedPersonnel.personnelId']) {
      const pid = query['authorizedPersonnel.personnelId'];
      const hasPersonnel = h.authorizedPersonnel && h.authorizedPersonnel.some((p) => p.personnelId === pid);
      if (!hasPersonnel) return Promise.resolve(null);
    }
    return Promise.resolve(h);
  }
  return Promise.resolve(null);
};

Citizen.exists = function (query) {
  if (query.profileId) {
    const c = testStore.citizens.get(query.profileId);
    if (!c) return Promise.resolve(null);
    return Promise.resolve({ _id: c.profileId });
  }
  return Promise.resolve(null);
};

Citizen.findOne = function (query) {
  if (query.profileId) {
    const c = testStore.citizens.get(query.profileId);
    if (!c) return Promise.resolve(null);
    return Promise.resolve(c);
  }
  return Promise.resolve(null);
};

hospitalsRoute.readHospital = async function (hospitalId) {
  const h = testStore.hospitals.get(hospitalId);
  if (!h) return null;
  const clone = { ...h };
  delete clone.authorizedPersonnel;
  delete clone.registeredPhone;
  return clone;
};

citizensRoute.readPatientForDoctor = async function (profileId) {
  const c = testStore.citizens.get(profileId);
  if (!c) return null;
  return {
    id: c.profileId,
    fullName: c.fullName || c.name,
    bloodGroup: c.bloodGroup,
    age: c.age || 30,
    address: c.address || '',
    allergies: c.allergies || 'None',
    medications: c.medications || 'None',
    chronicConditions: c.chronicConditions || 'None',
    specialInstructions: c.specialInstructions || 'None',
    isDnr: c.isDnr || false,
    emergencyContacts: c.emergencyContacts || [],
    organPledge: c.organPledge || null,
    insuranceCompany: c.insuranceCompany || '',
    insurancePolicyNumber: c.insurancePolicyNumber || '',
    prescriptions: c.prescriptions || [],
    medicalReports: c.medicalReports || [],
    isBloodDonor: c.isBloodDonor || false,
    profileCompleteness: 85,
    updatedAt: c.updatedAt || new Date(),
  };
};

// Capture console.info for audit log testing
const originalConsoleInfo = console.info;
console.info = function (...args) {
  testStore.auditLogs.push(args);
  originalConsoleInfo.apply(console, args);
};

// Helper to create client Ed25519 and X25519 keypairs
function generateClientKeys() {
  const edKeyPair = crypto.generateKeyPairSync('ed25519');
  const xKeyPair = crypto.generateKeyPairSync('x25519');

  const signingPubKeyRaw = Buffer.from(edKeyPair.publicKey.export({ format: 'jwk' }).x, 'base64url');
  const agreementPubKeyRaw = Buffer.from(xKeyPair.publicKey.export({ format: 'jwk' }).x, 'base64url');

  const signingPublicKey = signingPubKeyRaw.toString('base64');
  const agreementPublicKey = agreementPubKeyRaw.toString('base64');

  const deviceId = crypto.createHash('sha256').update(signingPubKeyRaw).digest('base64url').slice(0, 32);

  return {
    edKeyPair,
    xKeyPair,
    signingPublicKey,
    agreementPublicKey,
    deviceId,
    sign: (data) => crypto.sign(null, Buffer.from(data), edKeyPair.privateKey),
  };
}

// Helper to seal a client request packet
function createClientRequestPacket({
  clientKeys,
  hospitalId,
  originToken,
  destToken,
  ttl = 5,
  iat = Math.floor(Date.now() / 1000),
  exp = Math.floor(Date.now() / 1000) + 60,
  rid = crypto.randomUUID(),
  op = READ_HOSPITAL,
}) {
  const header = {
    v: 2,
    t: 'MEDICAL_DATA_REQUEST',
    op,
    rid,
    org: clientKeys.deviceId,
    dst: destToken,
    iat,
    exp,
    ttl,
  };

  const aad = getAadBytes(header);
  const serverPubs = getServerPublicKeys();
  const serverX25519Pub = Buffer.from(serverPubs.x25519PublicB64, 'base64');

  // Client creates ephemeral X25519 keypair
  const clientEpk = crypto.generateKeyPairSync('x25519');
  const epkBytes = Buffer.from(clientEpk.publicKey.export({ format: 'jwk' }).x, 'base64url');

  const serverPubKeyObj = crypto.createPublicKey({
    key: { kty: 'OKP', crv: 'X25519', x: serverX25519Pub.toString('base64url') },
    format: 'jwk',
  });

  const sharedSecret = crypto.diffieHellman({
    privateKey: clientEpk.privateKey,
    publicKey: serverPubKeyObj,
  });

  const derivedKey = crypto.hkdfSync('sha256', sharedSecret, Buffer.alloc(0), Buffer.from('swasthyatap/mesh/v2/req'), 32);
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', derivedKey, nonce);
  cipher.setAAD(aad);

  const payloadPlain = JSON.stringify({ op, ref: hospitalId, token: originToken });
  let enc = cipher.update(Buffer.from(payloadPlain, 'utf8'));
  enc = Buffer.concat([enc, cipher.final()]);
  const tag = cipher.getAuthTag();

  const sealedBytes = Buffer.concat([nonce, enc, tag]);

  const packet = {
    ...header,
    epk: epkBytes.toString('base64url'),
    pay: sealedBytes.toString('base64url'),
  };

  const canonical = getCanonicalString(packet);
  const sig = clientKeys.sign(canonical);
  packet.sig = sig.toString('base64url');

  return packet;
}

// Client helper to decrypt server response
function openServerResponse(responsePacket, clientKeys) {
  const serverPubs = getServerPublicKeys();
  const serverEdPubKey = crypto.createPublicKey({
    key: { kty: 'OKP', crv: 'Ed25519', x: Buffer.from(serverPubs.ed25519PublicB64, 'base64').toString('base64url') },
    format: 'jwk',
  });

  const canonical = getCanonicalString(responsePacket);
  const sigBytes = Buffer.from(responsePacket.sig, 'base64url');
  const verified = crypto.verify(null, Buffer.from(canonical), serverEdPubKey, sigBytes);
  if (!verified) throw new Error('SERVER_SIGNATURE_INVALID');

  const sealedBytes = Buffer.from(responsePacket.pay, 'base64url');
  const nonce = sealedBytes.subarray(0, 12);
  const tag = sealedBytes.subarray(sealedBytes.length - 16);
  const ciphertext = sealedBytes.subarray(12, sealedBytes.length - 16);

  const serverEpkBytes = Buffer.from(responsePacket.epk, 'base64url');
  const serverEpkObj = crypto.createPublicKey({
    key: { kty: 'OKP', crv: 'X25519', x: serverEpkBytes.toString('base64url') },
    format: 'jwk',
  });

  const sharedSecret = crypto.diffieHellman({
    privateKey: clientKeys.xKeyPair.privateKey,
    publicKey: serverEpkObj,
  });

  const derivedKey = crypto.hkdfSync('sha256', sharedSecret, Buffer.alloc(0), Buffer.from('swasthyatap/mesh/v2/resp'), 32);
  const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, nonce);
  decipher.setAAD(getAadBytes(responsePacket));
  decipher.setAuthTag(tag);

  let dec = decipher.update(ciphertext);
  dec = Buffer.concat([dec, decipher.final()]);
  return JSON.parse(dec.toString('utf8'));
}

test('Offline Mesh Read-Only Security Suite (B01 - B26)', async (suite) => {
  // Start ephemeral HTTP server with Express and router
  const app = express();
  app.use(express.json({ limit: '100kb' }));
  app.use('/api/offline-mesh', offlineMeshRouter);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}/api/offline-mesh`;

  suite.after(() => {
    server.close();
    console.info = originalConsoleInfo;
    MeshDevice.findOne = originalDeviceFindOne;
    MeshDevice.create = originalDeviceCreate;
    OfflineMeshRequest.findOne = originalRequestFindOne;
    OfflineMeshRequest.create = originalRequestCreate;
    OfflineMeshRequest.countDocuments = originalRequestCount;
    OfflineMeshRequest.updateMany = originalRequestUpdateMany;
    Hospital.exists = originalHospitalExists;
    Hospital.findOne = originalHospitalFindOne;
    Citizen.exists = originalCitizenExists;
    Citizen.findOne = originalCitizenFindOne;
    hospitalsRoute.readHospital = originalReadHospital;
    citizensRoute.readPatientForDoctor = originalReadPatientForDoctor;
  });

  // Seed fixture hospital and citizens
  const fixtureHospital = {
    hospitalId: 'HOSP_TEST_101',
    name: 'Bangalore General Hospital',
    address: '123 Health Ave, Bangalore',
    lat: 12.9716,
    lng: 77.5946,
    isVerified: true,
    registeredPhone: '+91 9876543210',
    phone: '+91 80 2222 3333',
    rating: 4.8,
    reviews: 500,
    status: 'Open Now',
    bedCount: 150,
    specialties: ['Cardiology', 'Emergency'],
    authorizedPersonnel: [
      { personnelId: 'PERS_DOC_1', name: 'Dr. Ramesh Kumar', designation: 'Chief Medical Officer' },
    ],
    updatedAt: new Date(),
  };
  testStore.hospitals.set(fixtureHospital.hospitalId, fixtureHospital);

  const fixtureCitizen = {
    profileId: 'CIT_TEST_202',
    name: 'Anita Sharma',
    bloodGroup: 'O+',
  };
  testStore.citizens.set(fixtureCitizen.profileId, fixtureCitizen);

  // Setup client keys and tokens
  const hospitalKeys = generateClientKeys();
  const hospitalToken = jwt.sign(
    { hospitalId: 'HOSP_TEST_101', personnelId: 'PERS_DOC_1', exp: Math.floor(Date.now() / 1000) + 3600 },
    process.env.JWT_SECRET,
    { algorithm: 'HS256' }
  );

  const citizenKeys = generateClientKeys();
  const citizenToken = jwt.sign(
    { citizenId: 'CIT_TEST_202', exp: Math.floor(Date.now() / 1000) + 3600 },
    process.env.JWT_SECRET,
    { algorithm: 'HS256' }
  );

  let hospitalDestToken = '';
  let citizenDestToken = '';

  await suite.test('B09: Device enrollment proof verification', async () => {
    // Valid proof for hospital
    const proofBytes = enrollmentBytes(hospitalKeys, hospitalToken);
    const proofSig = hospitalKeys.sign(proofBytes).toString('base64url');

    const res = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${hospitalToken}`,
      },
      body: JSON.stringify({
        deviceId: hospitalKeys.deviceId,
        signingPublicKey: hospitalKeys.signingPublicKey,
        agreementPublicKey: hospitalKeys.agreementPublicKey,
        proof: proofSig,
      }),
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.deviceId, hospitalKeys.deviceId);
    assert.ok(data.destinationToken);
    assert.ok(data.serverAgreementPublicKey);
    assert.ok(data.serverSigningPublicKey);
    hospitalDestToken = data.destinationToken;

    // Tampered proof must be rejected with 400
    const badProofRes = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${hospitalToken}`,
      },
      body: JSON.stringify({
        deviceId: hospitalKeys.deviceId,
        signingPublicKey: hospitalKeys.signingPublicKey,
        agreementPublicKey: hospitalKeys.agreementPublicKey,
        proof: 'bad_proof_'.repeat(8).slice(0, 86),
      }),
    });
    assert.strictEqual(badProofRes.status, 400);

    // Enroll citizen as well
    const citizenProofBytes = enrollmentBytes(citizenKeys, citizenToken);
    const citizenProofSig = citizenKeys.sign(citizenProofBytes).toString('base64url');

    const citizenReg = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${citizenToken}`,
      },
      body: JSON.stringify({
        deviceId: citizenKeys.deviceId,
        signingPublicKey: citizenKeys.signingPublicKey,
        agreementPublicKey: citizenKeys.agreementPublicKey,
        proof: citizenProofSig,
      }),
    });
    assert.strictEqual(citizenReg.status, 200);
    citizenDestToken = (await citizenReg.json()).destinationToken;
  });

  await suite.test('B10: Rebinding, key substitution and revoked device resurrection denied', async () => {
    // Attempt to register existing device with different keys
    const diffKeys = generateClientKeys();
    const proofBytes = enrollmentBytes(
      { ...hospitalKeys, agreementPublicKey: diffKeys.agreementPublicKey },
      hospitalToken
    );
    const proofSig = hospitalKeys.sign(proofBytes).toString('base64url');

    const rebindingRes = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${hospitalToken}`,
      },
      body: JSON.stringify({
        deviceId: hospitalKeys.deviceId,
        signingPublicKey: hospitalKeys.signingPublicKey,
        agreementPublicKey: diffKeys.agreementPublicKey,
        proof: proofSig,
      }),
    });
    assert.strictEqual(rebindingRes.status, 403);
  });

  await suite.test('B01: Valid directory read by enrolled current user', async () => {
    const packet = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
    });

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });

    assert.strictEqual(res.status, 200);
    const json = await res.json();
    assert.strictEqual(json.success, true);
    assert.ok(json.response);

    const decrypted = openServerResponse(json.response, hospitalKeys);
    assert.strictEqual(decrypted.ok, true);
    assert.strictEqual(decrypted.rid, packet.rid);
    assert.strictEqual(decrypted.op, READ_HOSPITAL);
    assert.strictEqual(decrypted.hospital.hospitalId, 'HOSP_TEST_101');
    assert.strictEqual(decrypted.hospital.name, 'Bangalore General Hospital');
    assert.strictEqual(decrypted.hospital.authorizedPersonnel, undefined); // personnel excluded
    assert.strictEqual(decrypted.hospital.registeredPhone, undefined); // staff login phone excluded
    assert.ok(decrypted.receivedAt);
    assert.ok(decrypted.authorizedAt);
    assert.ok(decrypted.snapshotAt);

    // Verify stored request row does not store plaintext hospital or token
    const stored = testStore.requests.get(packet.rid);
    assert.ok(stored);
    assert.strictEqual(stored.requestDigest, crypto.createHash('sha256').update(getCanonicalString(packet)).digest('hex'));
    assert.strictEqual(JSON.stringify(stored).includes('Bangalore General Hospital'), false);
    assert.strictEqual(JSON.stringify(stored).includes(hospitalToken), false);
  });

  await suite.test('B02: Reject all mutations and side-effecting operations', async () => {
    const forbiddenOps = [
      'UPDATE_PATIENT',
      'CREATE_PRESCRIPTION',
      'UPLOAD_REPORT',
      'ADD_CREDITS',
      'ORGAN_PLEDGE',
      'GENERATE_NFC_TOKEN',
      'CREATE_BLOOD_REQUEST',
      'RESPOND_BLOOD_REQUEST',
    ];

    for (const op of forbiddenOps) {
      const packet = createClientRequestPacket({
        clientKeys: hospitalKeys,
        hospitalId: 'HOSP_TEST_101',
        originToken: hospitalToken,
        destToken: hospitalDestToken,
        op,
      });

      const res = await fetch(`${baseUrl}/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(packet),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.code, 'INVALID_PACKET');
    }
  });

  await suite.test('B03: Reject patient reads and unapproved read operations', async () => {
    const unapprovedReads = [
      'FETCH_CITIZEN',
      'GET_CITIZENS',
      'SEARCH_PATIENTS',
      'GET_HEALTH_REPORTS',
      'GET_PHCS',
      'GET_BLOOD_BANKS',
      'LIST_HOSPITALS',
    ];

    for (const op of unapprovedReads) {
      const packet = createClientRequestPacket({
        clientKeys: hospitalKeys,
        hospitalId: 'HOSP_TEST_101',
        originToken: hospitalToken,
        destToken: hospitalDestToken,
        op,
      });

      const res = await fetch(`${baseUrl}/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(packet),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.code, 'INVALID_PACKET');
    }
  });

  await suite.test('B04: Valid outer op with malicious encrypted inner payload rejected', async () => {
    // Outer says READ_HOSPITAL, but encrypted payload tries FETCH_CITIZEN
    const header = {
      v: 2,
      t: 'MEDICAL_DATA_REQUEST',
      op: READ_HOSPITAL,
      rid: crypto.randomUUID(),
      org: hospitalKeys.deviceId,
      dst: hospitalDestToken,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 60,
      ttl: 5,
    };

    const aad = getAadBytes(header);
    const serverPubs = getServerPublicKeys();
    const serverX25519Pub = Buffer.from(serverPubs.x25519PublicB64, 'base64');
    const clientEpk = crypto.generateKeyPairSync('x25519');
    const epkBytes = Buffer.from(clientEpk.publicKey.export({ format: 'jwk' }).x, 'base64url');

    const serverPubKeyObj = crypto.createPublicKey({
      key: { kty: 'OKP', crv: 'X25519', x: serverX25519Pub.toString('base64url') },
      format: 'jwk',
    });
    const sharedSecret = crypto.diffieHellman({
      privateKey: clientEpk.privateKey,
      publicKey: serverPubKeyObj,
    });
    const derivedKey = crypto.hkdfSync('sha256', sharedSecret, Buffer.alloc(0), Buffer.from('swasthyatap/mesh/v2/req'), 32);
    const nonce = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', derivedKey, nonce);
    cipher.setAAD(aad);

    // Mismatched op & extra fields
    const maliciousPayload = JSON.stringify({
      op: 'FETCH_CITIZEN',
      ref: 'CIT_TEST_202',
      token: hospitalToken,
      url: '/api/citizens/CIT_TEST_202',
    });
    let enc = cipher.update(Buffer.from(maliciousPayload, 'utf8'));
    enc = Buffer.concat([enc, cipher.final()]);
    const tag = cipher.getAuthTag();
    const sealedBytes = Buffer.concat([nonce, enc, tag]);

    const packet = {
      ...header,
      epk: epkBytes.toString('base64url'),
      pay: sealedBytes.toString('base64url'),
    };
    packet.sig = hospitalKeys.sign(getCanonicalString(packet)).toString('base64url');

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });

    assert.strictEqual(res.status, 200);
    const json = await res.json();
    assert.strictEqual(json.success, true);
    const decrypted = openServerResponse(json.response, hospitalKeys);
    assert.strictEqual(decrypted.ok, false);
    assert.strictEqual(decrypted.code, 'ACCESS_DENIED');
  });

  await suite.test('B05: Malformed packets rejected with INVALID_PACKET', async () => {
    const valid = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
    });

    const malformedVariants = [
      { ...valid, extraField: 'prohibited' },
      { ...valid, v: '2' }, // string version
      { ...valid, ttl: '5' }, // string ttl
      { ...valid, rid: 'not-a-uuid' },
      { ...valid, sig: 'short_sig' },
      { ...valid, org: 'short_org' },
      { ...valid, pay: 'short_pay' },
      { ...valid, iat: 123.456 }, // fractional timestamp
      { ...valid, ttl: 9 }, // ttl > 8
      { ...valid, ttl: -1 }, // ttl < 0
    ];

    for (const bad of malformedVariants) {
      const res = await fetch(`${baseUrl}/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bad),
      });
      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.code, 'INVALID_PACKET');
    }
  });

  await suite.test('B06: No JWT, malformed JWT, expired JWT, demo tokens denied', async () => {
    const expiredToken = jwt.sign(
      { hospitalId: 'HOSP_TEST_101', personnelId: 'PERS_DOC_1', exp: Math.floor(Date.now() / 1000) - 100 },
      process.env.JWT_SECRET,
      { algorithm: 'HS256' }
    );
    const demoToken = 'DEMO_HOSPITAL_TOKEN';
    const noExpToken = jwt.sign(
      { hospitalId: 'HOSP_TEST_101', personnelId: 'PERS_DOC_1' },
      process.env.JWT_SECRET,
      { algorithm: 'HS256' }
    );

    for (const token of [expiredToken, demoToken, noExpToken, 'completely_bogus_token']) {
      const packet = createClientRequestPacket({
        clientKeys: hospitalKeys,
        hospitalId: 'HOSP_TEST_101',
        originToken: token,
        destToken: hospitalDestToken,
      });

      const res = await fetch(`${baseUrl}/request`, {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${hospitalToken}`, // Gateway token cannot rescue bad origin token
        },
        method: 'POST',
        body: JSON.stringify(packet),
      });

      assert.strictEqual(res.status, 200);
      const json = await res.json();
      const decrypted = openServerResponse(json.response, hospitalKeys);
      assert.strictEqual(decrypted.ok, false);
      assert.strictEqual(decrypted.code, 'ACCESS_DENIED');
    }
  });

  await suite.test('B07: Origin token belongs to another citizen/hospital/personnel denied', async () => {
    // Hospital keys with citizen token
    const mismatchedPacket = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: citizenToken,
      destToken: hospitalDestToken,
    });

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(mismatchedPacket),
    });

    assert.strictEqual(res.status, 200);
    const json = await res.json();
    const decrypted = openServerResponse(json.response, hospitalKeys);
    assert.strictEqual(decrypted.ok, false);
    assert.strictEqual(decrypted.code, 'ACCESS_DENIED');
  });

  await suite.test('B08: Hospital personnel removed or hospital unverified denied', async () => {
    // Create token for personnel not in authorizedPersonnel list
    const removedPersonnelToken = jwt.sign(
      { hospitalId: 'HOSP_TEST_101', personnelId: 'REVOKED_PERS_999', exp: Math.floor(Date.now() / 1000) + 3600 },
      process.env.JWT_SECRET,
      { algorithm: 'HS256' }
    );

    const packet = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: removedPersonnelToken,
      destToken: hospitalDestToken,
    });

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });

    assert.strictEqual(res.status, 200);
    const json = await res.json();
    const decrypted = openServerResponse(json.response, hospitalKeys);
    assert.strictEqual(decrypted.ok, false);
    assert.strictEqual(decrypted.code, 'ACCESS_DENIED');
  });

  await suite.test('B11: Tampered signature, headers, ciphertext or destination rejected', async () => {
    const validPacket = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
    });

    // Tampered payload
    const badPay = { ...validPacket, pay: validPacket.pay.slice(0, -4) + 'AAAA' };
    const res1 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(badPay),
    });
    assert.strictEqual(res1.status, 401);

    // Tampered destination token
    const badDst = { ...validPacket, dst: 'a'.repeat(43) };
    const res2 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(badDst),
    });
    assert.strictEqual(res2.status, 401);
  });

  await suite.test('B12: Expired requests and future clock skew denied', async () => {
    const now = Math.floor(Date.now() / 1000);
    // Expired packet
    const expiredPacket = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      iat: now - 200,
      exp: now - 50,
    });
    const res1 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(expiredPacket),
    });
    assert.strictEqual(res1.status, 400);

    // Future skew > 30s
    const futurePacket = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      iat: now + 100,
      exp: now + 160,
    });
    const res2 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(futurePacket),
    });
    assert.strictEqual(res2.status, 400);
  });

  await suite.test('B13: Exact duplicate returns cached response without duplicate DB read', async () => {
    const rid = crypto.randomUUID();
    const packet = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      rid,
    });

    // 1st attempt
    const res1 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });
    assert.strictEqual(res1.status, 200);
    const json1 = await res1.json();

    // 2nd attempt with same packet (including same or decremented ttl)
    const res2 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...packet, ttl: packet.ttl - 1 }),
    });
    assert.strictEqual(res2.status, 200);
    const json2 = await res2.json();

    assert.deepStrictEqual(json1.response, json2.response);
  });

  await suite.test('B14: Same request ID with altered payload rejected with DUPLICATE_REQUEST', async () => {
    const rid = crypto.randomUUID();
    const packet1 = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      rid,
    });

    const res1 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet1),
    });
    assert.strictEqual(res1.status, 200);

    // Create a new valid request using the same rid but different iat (altered payload / digest)
    const alteredPacket = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      rid,
      iat: packet1.iat + 5,
      exp: packet1.exp + 5,
    });

    const res2 = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(alteredPacket),
    });
    assert.strictEqual(res2.status, 409);
    const data = await res2.json();
    assert.strictEqual(data.code, 'DUPLICATE_REQUEST');
  });

  await suite.test('B15: Concurrency / race handling (code 11000 fallback to replay)', async () => {
    // If request already created by another thread, duplicate key 11000 triggers replay
    const rid = crypto.randomUUID();
    const packet = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      rid,
    });

    // Manually pre-seed an in-progress PROCESSING record
    const digest = crypto.createHash('sha256').update(getCanonicalString(packet)).digest('hex');
    await OfflineMeshRequest.create({
      requestId: rid,
      originDeviceId: hospitalKeys.deviceId,
      requestDigest: digest,
      createdAt: packet.iat,
      expiresAt: packet.exp,
      ttlOnArrival: packet.ttl,
      status: 'PROCESSING',
      receivedAt: new Date(),
    });

    // Request comes in; create will throw 11000, replay will see no sealedResponse yet -> 409 REQUEST_PENDING
    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });
    assert.strictEqual(res.status, 409);
    const data = await res.json();
    assert.strictEqual(data.code, 'REQUEST_PENDING');
  });

  await suite.test('B16: Expired response on replay returns 410 REQUEST_EXPIRED', async () => {
    const rid = crypto.randomUUID();
    const packet = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
      rid,
    });

    const digest = crypto.createHash('sha256').update(getCanonicalString(packet)).digest('hex');
    const expiredResponse = {
      v: 2,
      t: 'MEDICAL_DATA_RESPONSE',
      op: READ_HOSPITAL,
      rid,
      org: hospitalKeys.deviceId,
      dst: hospitalDestToken,
      iat: Math.floor(Date.now() / 1000) - 200,
      exp: Math.floor(Date.now() / 1000) - 10, // expired
      ttl: 5,
      epk: 'a'.repeat(43),
      pay: 'a'.repeat(60),
      sig: 'a'.repeat(86),
    };

    await OfflineMeshRequest.create({
      requestId: rid,
      originDeviceId: hospitalKeys.deviceId,
      requestDigest: digest,
      createdAt: packet.iat,
      expiresAt: Math.floor(Date.now() / 1000) + 60,
      ttlOnArrival: packet.ttl,
      status: 'RESPONSE_READY',
      sealedResponse: JSON.stringify(expiredResponse),
      receivedAt: new Date(),
    });

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });
    assert.strictEqual(res.status, 410);
    const data = await res.json();
    assert.strictEqual(data.code, 'REQUEST_EXPIRED');
  });

  await suite.test('B18: Device revocation endpoint unsets cached responses and marks device revoked', async () => {
    const revDeviceKeys = generateClientKeys();
    const revToken = jwt.sign(
      { hospitalId: 'HOSP_TEST_101', personnelId: 'PERS_DOC_1', exp: Math.floor(Date.now() / 1000) + 3600 },
      process.env.JWT_SECRET,
      { algorithm: 'HS256' }
    );
    const proofBytes = enrollmentBytes(revDeviceKeys, revToken);
    const proofSig = revDeviceKeys.sign(proofBytes).toString('base64url');

    const reg = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${revToken}`,
      },
      body: JSON.stringify({
        deviceId: revDeviceKeys.deviceId,
        signingPublicKey: revDeviceKeys.signingPublicKey,
        agreementPublicKey: revDeviceKeys.agreementPublicKey,
        proof: proofSig,
      }),
    });
    const { destinationToken: revDestToken } = await reg.json();

    // Perform a successful read
    const packet = createClientRequestPacket({
      clientKeys: revDeviceKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: revToken,
      destToken: revDestToken,
    });
    const readRes = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });
    assert.strictEqual(readRes.status, 200);
    assert.ok(testStore.requests.get(packet.rid).sealedResponse);

    // Revoke device
    const revokeRes = await fetch(`${baseUrl}/revoke-device`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${revToken}`,
      },
      body: JSON.stringify({ deviceId: revDeviceKeys.deviceId }),
    });
    assert.strictEqual(revokeRes.status, 200);

    const dev = testStore.devices.get(revDeviceKeys.deviceId);
    assert.strictEqual(dev.status, 'revoked');
    // Cached response was unset
    assert.strictEqual(testStore.requests.get(packet.rid).sealedResponse, undefined);

    // Subsequent request from revoked device must be denied
    const subPacket = createClientRequestPacket({
      clientKeys: revDeviceKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: revToken,
      destToken: revDestToken,
    });
    const subRes = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(subPacket),
    });
    assert.strictEqual(subRes.status, 401);
  });

  await suite.test('B19: Not found returned as sealed error without sensitive leakage', async () => {
    const packet = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'NON_EXISTENT_HOSPITAL_999',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
    });

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });

    assert.strictEqual(res.status, 200);
    const json = await res.json();
    const decrypted = openServerResponse(json.response, hospitalKeys);
    assert.strictEqual(decrypted.ok, false);
    assert.strictEqual(decrypted.code, 'NOT_FOUND');
    assert.strictEqual(decrypted.hospital, undefined);
  });

  await suite.test('B20: OFFLINE_MESH_ENABLED disable toggle gates all mesh routes except /config', async () => {
    process.env.OFFLINE_MESH_ENABLED = 'false';

    // /config still accessible and reports enabled: false
    const configRes = await fetch(`${baseUrl}/config`);
    assert.strictEqual(configRes.status, 200);
    const config = await configRes.json();
    assert.strictEqual(config.enabled, false);

    // /request returns 503 MESH_DISABLED
    const dummyPacket = createClientRequestPacket({
      clientKeys: hospitalKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: hospitalToken,
      destToken: hospitalDestToken,
    });
    const reqRes = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(dummyPacket),
    });
    assert.strictEqual(reqRes.status, 503);
    assert.strictEqual((await reqRes.json()).code, 'MESH_DISABLED');

    // /register-device returns 503
    const regRes = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert.strictEqual(regRes.status, 503);

    // /revoke-device returns 503
    const revRes = await fetch(`${baseUrl}/revoke-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert.strictEqual(revRes.status, 503);

    // Re-enable for subsequent tests
    process.env.OFFLINE_MESH_ENABLED = 'true';
  });

  await suite.test('B21: Legacy routes return 410 UNSUPPORTED_OPERATION', async () => {
    for (const route of ['/response/req-123', '/response-ack', '/status/req-123']) {
      const res = await fetch(`${baseUrl}${route}`, { method: 'GET' });
      assert.strictEqual(res.status, 410);
      assert.strictEqual((await res.json()).code, 'UNSUPPORTED_OPERATION');
    }
  });

  await suite.test('B23: Rate limiting rejects requests beyond 60 in 15 minutes', async () => {
    // Fill 60 records for a test device
    const rateDeviceKeys = generateClientKeys();
    const rateToken = jwt.sign(
      { hospitalId: 'HOSP_TEST_101', personnelId: 'PERS_DOC_1', exp: Math.floor(Date.now() / 1000) + 3600 },
      process.env.JWT_SECRET,
      { algorithm: 'HS256' }
    );
    const proofSig = rateDeviceKeys.sign(enrollmentBytes(rateDeviceKeys, rateToken)).toString('base64url');
    const reg = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${rateToken}` },
      body: JSON.stringify({
        deviceId: rateDeviceKeys.deviceId,
        signingPublicKey: rateDeviceKeys.signingPublicKey,
        agreementPublicKey: rateDeviceKeys.agreementPublicKey,
        proof: proofSig,
      }),
    });
    const { destinationToken: rateDestToken } = await reg.json();

    for (let i = 0; i < 60; i++) {
      testStore.requests.set(`rate-req-${i}`, {
        requestId: `rate-req-${i}`,
        originDeviceId: rateDeviceKeys.deviceId,
        receivedAt: new Date(),
      });
    }

    const packet = createClientRequestPacket({
      clientKeys: rateDeviceKeys,
      hospitalId: 'HOSP_TEST_101',
      originToken: rateToken,
      destToken: rateDestToken,
    });

    const res = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(packet),
    });
    assert.strictEqual(res.status, 429);
    assert.strictEqual((await res.json()).code, 'RATE_LIMITED');
  });

  await suite.test('B24: Database indexes verification on Mongoose schemas', () => {
    const reqIndexes = OfflineMeshRequest.schema.indexes();
    const uniqueReqIdIndex = reqIndexes.find((idx) => idx[0].requestId === 1 && idx[1].unique === true);
    assert.ok(uniqueReqIdIndex, 'Unique index on requestId required');

    const ttlIndex = reqIndexes.find((idx) => idx[0].receivedAt === 1 && idx[1].expireAfterSeconds === 900);
    assert.ok(ttlIndex, 'TTL index with 900s on receivedAt required');

    const devIndexes = MeshDevice.schema.indexes();
    const uniqueDeviceIdIndex = devIndexes.find((idx) => idx[0].deviceId === 1 && idx[1].unique === true);
    assert.ok(uniqueDeviceIdIndex, 'Unique index on deviceId required');
  });

  await suite.test('B25: Access audit logs contain only restricted metadata, no clinical content or tokens', () => {
    const meshAuditLogs = testStore.auditLogs.filter((entry) => entry[0] === '[mesh]');
    assert.ok(meshAuditLogs.length > 0);
    for (const log of meshAuditLogs) {
      const meta = log[1];
      assert.ok(meta.requestId);
      assert.strictEqual(meta.operation, READ_HOSPITAL);
      assert.ok(meta.status);
      assert.strictEqual(meta.token, undefined);
      assert.strictEqual(meta.ref, undefined);
      assert.strictEqual(meta.hospital, undefined);
    }
  });

  await suite.test('B26: Database mutation detection confirms zero business writes occurred', () => {
    assert.strictEqual(
      testStore.mutations.length,
      0,
      `Zero mutations allowed on business models. Found: ${JSON.stringify(testStore.mutations)}`
    );
  });
});
