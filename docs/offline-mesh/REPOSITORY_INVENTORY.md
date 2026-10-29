# Repository inventory and operation eligibility

**Inspection date:** 24 October 2026. This inventory describes local source and verified implementation artifacts. “Existing” means present before mesh enhancements; “implemented” refers to verified additions in the current working tree. See [handoff](IMPLEMENTATION_HANDOFF.md).

---

## 1. Existing System Components & Reuse

| Concern | Source Evidence | Reuse Decision and Limits |
| --- | --- | --- |
| Mobile stack | [`pubspec.yaml`](../../pubspec.yaml), [`lib/main.dart`](../../lib/main.dart) | Flutter/Dart, Provider. Directive order fixed in `main.dart`. Keeps existing application architecture and navigation intact |
| HTTP client | [`api_service.dart`](../../lib/services/api_service.dart) | Continues using `ApiService` and `http`. Removed deprecated legacy `pollMeshResponse` and `ackMeshResponse` helpers. Directive order fixed |
| Auth issuer | [auth.js routes](../../backend/src/routes/auth.js) | Reuses existing signed JWTs and secret. Citizen claims include `citizenId`; hospital claims include `hospitalId` and `personnelId` |
| Auth middleware | [middleware/auth.js](../../backend/src/middleware/auth.js), [`meshAccess.js`](../../backend/src/services/meshAccess.js) | Existing `authenticate` middleware accepts demo tokens; `meshAccess.js` enforces strict verification, derives role from real claims, rejects demo tokens, checks active hospital personnel or citizen existence, and validates enrollment proofs |
| Session persistence | [auth_storage.dart](../../lib/services/auth_storage.dart) | Uses SharedPreferences for online session tokens; `DeviceIdentity` uses Flutter Secure Storage for Ed25519/X25519 private keys |
| Device identity | [device_identity.dart](../../lib/services/offline_mesh/device_identity.dart), [MeshDevice.js](../../backend/src/models/MeshDevice.js) | Existing Ed25519/X25519 key pairs, owner binding fields, active/revoked status; reused without new identity infrastructure |
| Cryptography | [crypto_manager.dart](../../lib/services/offline_mesh/crypto_manager.dart), [`meshCrypto.js`](../../backend/src/services/meshCrypto.js) | Existing `cryptography` library in Dart and Node `crypto`. Cross-language vectors generated and verified in `meshVectors.test.js` (C01–C08) |
| Server and hosting | [index.js](../../backend/src/index.js), [vercel.json](../../backend/vercel.json) | Express/CommonJS, Mongoose. Router-wide `OFFLINE_MESH_ENABLED` gate added. No new external servers or persistent socket infrastructure |
| Business data | [Hospital.js](../../backend/src/models/Hospital.js), [Citizen.js](../../backend/src/models/Citizen.js), [NfcCard.js](../../backend/src/models/NfcCard.js), [HealthReport.js](../../backend/src/models/HealthReport.js) | Existing collections and queries reused. Zero schema changes to hospital or patient collections |
| Hospital detail query | [`hospitals.js`](../../backend/src/routes/hospitals.js) | Extracted `readHospital()` shared between online route and mesh dispatcher. Verified in B01 |
| Transport | [nearby_transport.dart](../../lib/services/offline_mesh/transport/nearby_transport.dart), [`peer_manager.dart`](../../lib/services/offline_mesh/peer_manager.dart) | Android Nearby transport; `PeerManager.addPeer()` triggers `connectToPeer()` for discovered disconnected peers |
| Local queue/routing | [`relay_cache.dart`](../../lib/services/offline_mesh/store/relay_cache.dart), [mesh_queue.dart](../../lib/services/offline_mesh/store/mesh_queue.dart), [mesh_database.dart](../../lib/services/offline_mesh/store/mesh_database.dart) | SQLite `mesh.db`. `RelayCache` completion methods updated to use `$packetType:$requestId`. Expired queued ciphertext safely deleted on sweeps |
| Server replay store | [`OfflineMeshRequest.js`](../../backend/src/models/OfflineMeshRequest.js) | Schema with unique `requestId` and 900-second TTL index. Replay cache release re-verifies active device status and server enablement |
| Logging | [mesh_logger.dart](../../lib/services/offline_mesh/mesh_logger.dart), [index.js](../../backend/src/index.js) | Restricted metadata logging only (`requestId`, `operation`, `status`). Verified in B25: no tokens, PII, or raw payloads logged |
| Tests and delivery | [`package.json`](../../backend/package.json), [`meshReadOnly.test.js`](../../backend/src/meshReadOnly.test.js), [`meshVectors.test.js`](../../backend/src/meshVectors.test.js) | Node test runner executes 39 tests with 39 PASS, 0 FAIL. Scoped to `src/**/*.test.js` |

---

## 2. Actual API Inventory & Mesh Disposition

Paths below include the `/api` prefix mounted by the server. “Excluded” means no mesh dispatch path exists.

| Existing Endpoint | Observed Server Access & Effects | Mesh Disposition |
| --- | --- | --- |
| `GET /hospitals/:hospitalId` | Public; `Hospital.findOne` excluding `authorizedPersonnel` | **Only candidate operation: `READ_HOSPITAL`**. Requires valid encrypted origin JWT, active principal, enrolled device. UI modal suppresses `registeredPhone` |
| `GET /hospitals` | Public; list/search | Excluded from mesh; no unbounded list forwarding |
| `GET /citizens` | Public; bulk search | Excluded; no per-record consent/access policy |
| `GET /citizens/:id` | Public; returns profile, medical history, prescriptions | Excluded; absence of endpoint auth is not authorization to relay patient data |
| `GET /citizens/:id/nfc-token` | `authenticate`; hospital claim or matching citizen; creates/updates card | **Forbidden mutation**, irrespective of HTTP GET |
| `PUT /citizens/:id` | `authenticate`; updates medical profile | Forbidden mutation |
| `POST /citizens/:id/prescriptions` | `authenticate`; uploads file and appends prescription | Forbidden mutation |
| `POST /citizens/:id/medical-reports` | `authenticate`; uploads file and appends medical report | Forbidden mutation |
| `POST /citizens/:id/organ-pledge` | `authenticate`; writes organ donation pledge | Forbidden mutation |
| `POST /citizens/:id/verify-organ-consent` | Public lookup comparing donation signature hash | Excluded; organ pledge verification is not medical-data access consent |
| `POST /citizens/:id/add-credits` | `authenticate`; increments citizen field | Forbidden mutation |
| `GET /health-reports` | `authenticate`; citizen history | Excluded; citizen submission history is not approved hospital-patient access |
| `GET /health-reports/summary` | Public disease aggregate | Excluded pending disclosure review |
| `POST /health-reports` | `authenticate`; creates report | Forbidden mutation |
| `GET /blood-requests`, `GET /blood-requests/:requestId` | Optional auth / public detail | Excluded; field-level authorization not established |
| `POST /blood-requests`, `PUT /blood-requests/:requestId/respond` | Authenticated emergency declaration / donor response | Forbidden mutations |
| `GET /phcs`, `GET /phcs/:phcId` | Public PHC metadata | Excluded; separate category not admitted by one-operation scope |
| `GET /blood-banks`, `GET /blood-banks/:bloodBankId` | Public blood-bank metadata | Excluded; separate category not admitted |
| `GET /orders/*`, `POST /orders` | Authenticated order management | Excluded; shopping/payment operations outside hospital-data mesh |
| `/auth/*` OTP and verification routes | Session establishment | Online enrollment prerequisite; never tunneled via mesh |

---

## 3. Hospital Detail Response & Field Classification

The query excludes `authorizedPersonnel`. The `Hospital` model includes directory fields (name, address, city, state, pincode, coordinates, phone), specialties, badges, ratings, verification status, bed counts, and `registeredPhone` (used for hospital staff login OTP).

**Field Minimization & Safety Gate (F15):**
- In the mobile client (`NearbyHealthCentersScreen`), `_HospitalDetailModal` displays only public contact `phone` and explicitly omits `registeredPhone`.
- Formal review is recommended to evaluate whether `registeredPhone` should also be projected out at the backend route level (`{ authorizedPersonnel: 0, registeredPhone: 0 }`) before production release.

---

## 4. Patient Consent & Access Findings

- No route-level patient-sharing permission check or hospital-to-patient access grant was found in the codebase.
- `organPledge.signatureHash` and `verify-organ-consent` are specific to organ donation and do not authorize clinical record disclosure.
- App participation consent (`mesh_consent`) controls whether a device relays packets; it does not constitute patient data disclosure consent.
- Hospital personnel membership proves staff status at a hospital, not a clinical treatment relationship with a specific patient.
- NFC card possession and client PIN bypass are not substitutes for server authorization.
- All patient-related operations remain strictly blocked from the mesh.

---

## 5. New or Changed Components: Verification Status

| Component | Technical Gap Addressed | Implementation Approach | Verification Status |
| --- | --- | --- | --- |
| `meshAccess.js` | Replaces demo-token-tolerant auth with strict origin validation and device binding | Thin adapter reusing existing JWT secret/library and models | Verified in B06–B10, B18 (all pass) |
| `mesh_read_policy.dart` | Closes queue and feature boundary to approved operation | Strict enum, identifier regex, payload constraints | Verified in B02–B05, M01–M03 |
| Extracted `readHospital()` | Eliminates duplicate query logic between online and mesh | Shared function in `hospitals.js` | Verified in B01 (online and mesh parity) |
| Mesh request metadata | Binds replay digest, separates receipt/authorization/snapshot times | Optional fields on `OfflineMeshRequest` model | Verified in B13–B16, B24 |
| v2 packet constraints | Exact 12-field envelope, canonical JSON, AAD binding | Strict validation in `meshValidation.js` and `offline_packet.dart` | Verified in B05, C01–C08 |
| Hospital UI & lifecycle hooks | Wires directory retrieval UI and lifecycle safety | `_HospitalDetailModal` with snapshot provenance; fail-safe teardown | Verified in mobile code; B21, F05, F21 |
