const test = require('node:test');
const assert = require('node:assert');
const http = require('http');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const express = require('express');

// Set test environment variables
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
} = require('./services/meshValidation');

const {
  enrollmentBytes,
} = require('./services/meshAccess');

test('Hospital Role-Based Access Control & Doctor Mesh Patient Access Suite', async (suite) => {
  const testStore = {
    devices: new Map(),
    requests: new Map(),
    hospitals: new Map(),
    citizens: new Map(),
  };

  // Mocks
  const origDeviceFindOne = MeshDevice.findOne;
  const origDeviceCreate = MeshDevice.create;
  const origRequestFindOne = OfflineMeshRequest.findOne;
  const origRequestCreate = OfflineMeshRequest.create;
  const origRequestCount = OfflineMeshRequest.countDocuments;
  const origHospitalExists = Hospital.exists;
  const origHospitalFindOne = Hospital.findOne;
  const origCitizenExists = Citizen.exists;
  const origCitizenFindOne = Citizen.findOne;
  const origReadPatient = citizensRoute.readPatientForDoctor;

  MeshDevice.findOne = query => Promise.resolve(query.deviceId ? testStore.devices.get(query.deviceId) || null : null);
  MeshDevice.create = doc => {
    const dev = { ...doc, status: 'active', save: async function() { testStore.devices.set(this.deviceId, this); return this; } };
    testStore.devices.set(doc.deviceId, dev);
    return Promise.resolve(dev);
  };
  OfflineMeshRequest.findOne = query => Promise.resolve(query.requestId ? testStore.requests.get(query.requestId) || null : null);
  OfflineMeshRequest.create = doc => {
    const rec = { ...doc, save: async function() { testStore.requests.set(this.requestId, this); return this; } };
    testStore.requests.set(doc.requestId, rec);
    return Promise.resolve(rec);
  };
  OfflineMeshRequest.countDocuments = () => Promise.resolve(0);

  Hospital.exists = query => {
    const h = testStore.hospitals.get(query.hospitalId);
    if (!h || (query.isVerified !== undefined && h.isVerified !== query.isVerified)) return Promise.resolve(null);
    if (query['authorizedPersonnel.personnelId']) {
      const pid = query['authorizedPersonnel.personnelId'];
      if (!h.authorizedPersonnel?.some(p => p.personnelId === pid)) return Promise.resolve(null);
    }
    return Promise.resolve({ _id: h.hospitalId });
  };
  Hospital.findOne = query => {
    const h = testStore.hospitals.get(query.hospitalId);
    if (!h || (query.isVerified !== undefined && h.isVerified !== query.isVerified)) return Promise.resolve(null);
    if (query['authorizedPersonnel.personnelId']) {
      const pid = query['authorizedPersonnel.personnelId'];
      if (!h.authorizedPersonnel?.some(p => p.personnelId === pid)) return Promise.resolve(null);
    }
    return Promise.resolve({
      ...h,
      save: async function() { testStore.hospitals.set(this.hospitalId, this); return this; }
    });
  };

  Citizen.exists = query => Promise.resolve(testStore.citizens.has(query.profileId) ? { _id: query.profileId } : null);
  Citizen.findOne = query => Promise.resolve(testStore.citizens.get(query.profileId) || null);

  citizensRoute.readPatientForDoctor = async profileId => {
    const c = testStore.citizens.get(profileId);
    if (!c) return null;
    return {
      id: c.profileId,
      fullName: c.fullName,
      bloodGroup: c.bloodGroup,
      allergies: c.allergies || 'Penicillin',
      chronicConditions: c.chronicConditions || 'Hypertension',
      emergencyContacts: c.emergencyContacts || [],
      prescriptions: c.prescriptions || [],
      profileCompleteness: 80,
    };
  };

  // Setup app & server
  const app = express();
  app.use(express.json());
  app.use('/api/hospitals', hospitalsRoute);
  app.use('/api/offline-mesh', offlineMeshRouter);

  const server = http.createServer(app);
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}/api/offline-mesh`;
  const hospitalUrl = `http://127.0.0.1:${port}/api/hospitals`;

  suite.after(() => {
    server.close();
    MeshDevice.findOne = origDeviceFindOne;
    MeshDevice.create = origDeviceCreate;
    OfflineMeshRequest.findOne = origRequestFindOne;
    OfflineMeshRequest.create = origRequestCreate;
    OfflineMeshRequest.countDocuments = origRequestCount;
    Hospital.exists = origHospitalExists;
    Hospital.findOne = origHospitalFindOne;
    Citizen.exists = origCitizenExists;
    Citizen.findOne = origCitizenFindOne;
    citizensRoute.readPatientForDoctor = origReadPatient;
  });

  // Seed data
  const hospitalData = {
    hospitalId: 'HOSP_METRO_01',
    name: 'Metro City Hospital',
    address: '45 MG Road, Bangalore',
    isVerified: true,
    bedCount: 120,
    status: 'Open Now',
    authorizedPersonnel: [
      { personnelId: 'DOC_001', name: 'Dr. Ramesh Sharma', designation: 'Cardiologist', role: 'doctor' },
      { personnelId: 'SUP_001', name: 'Sarah Joseph', designation: 'Chief Administrator', role: 'supervisor' },
    ],
  };
  testStore.hospitals.set(hospitalData.hospitalId, hospitalData);

  const citizenData = {
    profileId: 'x7k9m2',
    fullName: 'Rajesh Kumar',
    bloodGroup: 'B+',
    allergies: 'Penicillin, Dust',
    chronicConditions: 'Asthma',
    emergencyContacts: [{ name: 'Sunita Kumar', relation: 'Spouse', phone: '+91 9876543210' }],
  };
  testStore.citizens.set(citizenData.profileId, citizenData);

  // Helper for generating keys
  function makeKeys() {
    const ed = crypto.generateKeyPairSync('ed25519');
    const x = crypto.generateKeyPairSync('x25519');
    const signingPublicKey = Buffer.from(ed.publicKey.export({ format: 'jwk' }).x, 'base64url').toString('base64');
    const agreementPublicKey = Buffer.from(x.publicKey.export({ format: 'jwk' }).x, 'base64url').toString('base64');
    const deviceId = crypto.createHash('sha256').update(Buffer.from(signingPublicKey, 'base64')).digest('base64url').slice(0, 32);
    return {
      deviceId, signingPublicKey, agreementPublicKey,
      sign: msg => crypto.sign(null, msg, ed.privateKey),
      agreementPrivateKey: x.privateKey,
    };
  }

  const doctorKeys = makeKeys();
  const supervisorKeys = makeKeys();
  const citizenKeys = makeKeys();

  const doctorToken = jwt.sign(
    { hospitalId: 'HOSP_METRO_01', personnelId: 'DOC_001', role: 'doctor', exp: Math.floor(Date.now() / 1000) + 3600 },
    process.env.JWT_SECRET
  );
  const supervisorToken = jwt.sign(
    { hospitalId: 'HOSP_METRO_01', personnelId: 'SUP_001', role: 'supervisor', exp: Math.floor(Date.now() / 1000) + 3600 },
    process.env.JWT_SECRET
  );
  const citizenToken = jwt.sign(
    { citizenId: 'x7k9m2', exp: Math.floor(Date.now() / 1000) + 3600 },
    process.env.JWT_SECRET
  );

  let doctorDestToken = '';
  let supervisorDestToken = '';

  // Register doctor device
  await suite.test('Enroll doctor device', async () => {
    const proof = doctorKeys.sign(enrollmentBytes(doctorKeys, doctorToken)).toString('base64url');
    const res = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${doctorToken}` },
      body: JSON.stringify({
        deviceId: doctorKeys.deviceId,
        signingPublicKey: doctorKeys.signingPublicKey,
        agreementPublicKey: doctorKeys.agreementPublicKey,
        proof,
      }),
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    doctorDestToken = data.destinationToken;
  });

  // Register supervisor device
  await suite.test('Enroll supervisor device', async () => {
    const proof = supervisorKeys.sign(enrollmentBytes(supervisorKeys, supervisorToken)).toString('base64url');
    const res = await fetch(`${baseUrl}/register-device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${supervisorToken}` },
      body: JSON.stringify({
        deviceId: supervisorKeys.deviceId,
        signingPublicKey: supervisorKeys.signingPublicKey,
        agreementPublicKey: supervisorKeys.agreementPublicKey,
        proof,
      }),
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    supervisorDestToken = data.destinationToken;
  });

  // Helper to seal request packet
  function createPacket({ keys, token, destToken, op, ref }) {
    const now = Math.floor(Date.now() / 1000);
    const rid = crypto.randomUUID();
    const serverAgreementKey = crypto.createPublicKey({
      key: { kty: 'OKP', crv: 'X25519', x: getServerPublicKeys().x25519PublicB64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '') },
      format: 'jwk',
    });
    const header = { v: 2, t: 'MEDICAL_DATA_REQUEST', op, rid, org: keys.deviceId, dst: destToken, iat: now, exp: now + 60, ttl: 5 };
    const aad = getAadBytes(header);
    const cleartext = JSON.stringify({ op, ref, token });
    const sealed = sealForDevice(JSON.parse(cleartext), serverAgreementKey.export({ type: 'spki', format: 'der' }).subarray(12).toString('base64'), aad, 'swasthyatap/mesh/v2/req');
    const packet = { ...header, ...sealed };
    packet.sig = keys.sign(Buffer.from(getCanonicalString(packet), 'utf8')).toString('base64url');
    return packet;
  }

  function decryptResponse(response, keys) {
    const sealedBytes = Buffer.from(response.pay, 'base64url');
    const nonce = sealedBytes.subarray(0, 12);
    const tag = sealedBytes.subarray(sealedBytes.length - 16);
    const ciphertext = sealedBytes.subarray(12, sealedBytes.length - 16);

    const serverEpkBytes = Buffer.from(response.epk, 'base64url');
    const serverEpkObj = crypto.createPublicKey({
      key: { kty: 'OKP', crv: 'X25519', x: serverEpkBytes.toString('base64url') },
      format: 'jwk',
    });

    const sharedSecret = crypto.diffieHellman({
      privateKey: keys.agreementPrivateKey,
      publicKey: serverEpkObj,
    });

    const derivedKey = crypto.hkdfSync('sha256', sharedSecret, Buffer.alloc(0), Buffer.from('swasthyatap/mesh/v2/resp'), 32);
    const decipher = crypto.createDecipheriv('aes-256-gcm', derivedKey, nonce);
    decipher.setAAD(getAadBytes(response));
    decipher.setAuthTag(tag);
    let decrypted = decipher.update(ciphertext);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return JSON.parse(decrypted.toString('utf8'));
  }

  await suite.test('Doctor can query patient data offline over mesh (READ_PATIENT)', async () => {
    const packet = createPacket({
      keys: doctorKeys,
      token: doctorToken,
      destToken: doctorDestToken,
      op: READ_PATIENT,
      ref: 'x7k9m2',
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

    const decrypted = decryptResponse(json.response, doctorKeys);
    assert.strictEqual(decrypted.ok, true);
    assert.strictEqual(decrypted.op, READ_PATIENT);
    assert.strictEqual(decrypted.rid, packet.rid);
    assert.strictEqual(decrypted.patient.id, 'x7k9m2');
    assert.strictEqual(decrypted.patient.fullName, 'Rajesh Kumar');
    assert.strictEqual(decrypted.patient.bloodGroup, 'B+');
    assert.strictEqual(decrypted.patient.allergies, 'Penicillin, Dust');
    assert.strictEqual(decrypted.patient.chronicConditions, 'Asthma');
    assert.strictEqual(decrypted.patient.emergencyContacts[0].name, 'Sunita Kumar');
  });

  await suite.test('Supervisor CANNOT query clinical patient data over mesh (access denied)', async () => {
    const packet = createPacket({
      keys: supervisorKeys,
      token: supervisorToken,
      destToken: supervisorDestToken,
      op: READ_PATIENT,
      ref: 'x7k9m2',
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

    const decrypted = decryptResponse(json.response, supervisorKeys);
    assert.strictEqual(decrypted.ok, false);
    assert.strictEqual(decrypted.code, 'ACCESS_DENIED');
    assert.strictEqual(decrypted.patient, undefined);
  });

  await suite.test('Supervisor REST RBAC: Supervisor can add new personnel', async () => {
    const res = await fetch(`${hospitalUrl}/HOSP_METRO_01/personnel`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${supervisorToken}` },
      body: JSON.stringify({
        personnelId: 'DOC_002',
        name: 'Dr. Priya Nair',
        designation: 'Neurologist',
        role: 'doctor',
      }),
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.personnel.some(p => p.personnelId === 'DOC_002'), true);
  });

  await suite.test('Doctor REST RBAC: Doctor CANNOT add personnel (403 Forbidden)', async () => {
    const res = await fetch(`${hospitalUrl}/HOSP_METRO_01/personnel`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${doctorToken}` },
      body: JSON.stringify({
        personnelId: 'DOC_003',
        name: 'Dr. Malicious',
        designation: 'Intern',
        role: 'doctor',
      }),
    });
    assert.strictEqual(res.status, 403);
    const data = await res.json();
    assert.strictEqual(data.success, false);
  });

  await suite.test('Doctor REST RBAC: Doctor can update hospital bed capacity', async () => {
    const res = await fetch(`${hospitalUrl}/HOSP_METRO_01/beds`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${doctorToken}` },
      body: JSON.stringify({ bedCount: 135 }),
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.bedCount, 135);
  });

  await suite.test('Supervisor REST RBAC: Supervisor can delete personnel', async () => {
    const res = await fetch(`${hospitalUrl}/HOSP_METRO_01/personnel/DOC_002`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${supervisorToken}` },
    });
    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.personnel.some(p => p.personnelId === 'DOC_002'), false);
  });
});
