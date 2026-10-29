# Security, privacy and data lifecycle

**Status:** Verified security specifications and controls for the read-only add-on. Backend integration suite (B01–B26) and cross-language crypto vector suite (C01–C08) are implemented and verified (39 passing tests). Production mesh remains disabled. See [handoff](IMPLEMENTATION_HANDOFF.md) and [test plan](TEST_AND_ACCEPTANCE_PLAN.md).

---

## 1. Assets and Trust Assumptions

Protect patient identity, medical content, hospital access-controlled fields, bearer credentials, private keys, consent state, access history, and request-target associations. Integrity, authorization, and freshness matter alongside confidentiality: a stale or unauthorized record can be dangerous even if transported in ciphertext.

The requesting user may be legitimate, logged out, or revoked. Nearby peers and gateways may drop, replay, modify, reorder, retain, or correlate traffic. Peer possession of valid credentials is not permission to read someone else's data. The backend, its key custody, and the existing database are trusted processing boundaries; compromising those boundaries cannot be solved by mesh encryption.

The originating device displays plaintext only after authorized decryption. A compromised/rooted origin, screen capture, exported documents, backups, and memory inspection are outside any claim that intermediaries cannot decrypt. The design reduces retention and relies on established device controls without promising impossible erasure or remote recall.

---

## 2. Read-Only Enforcement at Five Layers

| Layer | Enforced Control | Verification Evidence |
| --- | --- | --- |
| Feature | Typed closed operation (`READ_HOSPITAL`), scalar ID regex `^[A-Za-z0-9_-]{1,80}$`, no generic method/body/URL entry point; patient requests rejected before discovery/queue | `requestMedicalData()` rejects locally; `requestHospital()` is sole mesh entry point; verified in M01–M03 |
| Protocol | Explicit v2 version, `MEDICAL_DATA_REQUEST` type, `READ_HOSPITAL` op, strict 12-field envelope, integer bounds, expiry, signature, and encrypted payload operation agreement | Verified in B04, B05, C01–C08 |
| Gateway | Fixed backend destination; allowlisted read envelope only; no redirects to caller URLs or arbitrary API tunnel | Gateway forwards ciphertext without bearer auth; verified in B02, B04 |
| Server | Verifies original JWT, current device/owner, principal, and operation-specific data policy; rejects all mutations before business dispatch | Verified in B01, B02, B03, B06, B07, B08, B09, B10, B11 |
| Database | Reuses existing `readHospital()` read; zero mesh paths to write methods; separate legitimate mesh control-plane bookkeeping from business data | Verified in B26: mutation spies confirm 0 business writes across Hospital, Citizen, and report models |

The application uses a shared database connection. Mutation detection in B26 proves that no hospital or citizen records are altered by mesh traffic.

---

## 3. Authorization and Consent

A server decision uses permissions valid **when the server processes the request**, not when it was created offline or when a peer accepted it. JWT expiration, current hospital membership, device revocation, and principal existence are checked on every processing run and retry. Exact retries are subject to reauthorization; cached ciphertext is never released to a revoked or unverified device.

The implementation reuses the issuer, signing secret, JWT library, and account models already present. It rejects literal demo tokens and derives roles from actual issuer claims (`citizenId`, `hospitalId`, `personnelId`). Existing online auth behavior is not rewritten.

For hospital-directory reads, a valid hospital principal must be verified and listed in `authorizedPersonnel`; a citizen principal must exist in the database. Device registration binds the response key to that principal. Changing a body `role`, signing as a gateway, or presenting a different user's token fails authorization.

For **patient records**, no record-specific access/consent policy exists in the codebase. All patient requests remain strictly denied at all layers. Donation pledge consent, device participation consent, NFC possession, and client PIN bypass do not constitute medical-data sharing permission.

---

## 4. End-to-End Encryption and Key Handling

Reuses existing X25519 key agreement, HKDF-SHA256, ChaCha20-Poly1305 AEAD, and Ed25519 signatures. The origin encrypts target reference and JWT to the backend public key; the backend encrypts results to the registered origin key. Intermediary relays and gateways possess neither private key and cannot decrypt traffic.

Server public keys are learned through authenticated HTTPS enrollment, not through peers. Cross-language golden vectors (`test/vectors/mesh_v2_vectors.json`) verify that the exact final envelope can be opened and verified between Node.js and Dart.

---

## 5. Threat / Control Verification Matrix

| Threat | Required Response | Verification Status |
| --- | --- | --- |
| Modified client sends mutation or GET with side effects | Deny operation before business dispatch; no arbitrary forwarding | **VERIFIED in B02, B04, B26:** All mutations return 400; zero business writes |
| Gateway supplies its own higher privilege token | Ignore it as origin authority; verify encrypted origin JWT and device binding | **VERIFIED in B06, B07:** Gateway auth ignored; invalid origin JWT rejected |
| Stolen public device ID used for enrollment | Proof of signing-key possession; immutable owner/key binding; no revoked-device reactivation | **VERIFIED in B09, B10:** Enrollment proof checked; rebinding/substitution denied |
| JWT expires or staff/consent is revoked while offline | Check current server state on processing and retry; deny stale permission | **VERIFIED in B06, B08, B12:** Expired tokens, removed personnel, unverified hospitals denied |
| Wrong-key or altered response | Verify server signature and origin/request binding before decryption/display | **VERIFIED in C01–C08, B11:** Tampered signatures/headers/ciphertext fail verification |
| Request-ID collision or replay | Bind to origin and canonical request digest; atomic unique ID; exact unexpired replay only | **VERIFIED in B13, B14, B15, B24:** Same payload returns cache; altered payload returns 409 |
| Retained stale response | Enforce absolute expiry independently of database TTL; UI must not mark it current | **VERIFIED in B12, B16:** Expired requests return 410; UI modal displays snapshot time |
| Peer loops / flooding | Hop/expiry limits, deduplication, queue/packet bounds, rate limiting | **VERIFIED in B23:** Rate limit enforced (60 req/15min); hop count decremented |
| Malicious errors/logs disclose data | Constant bounded codes; sealed application errors; allowlisted logs; neutral UI | **VERIFIED in B19, B25:** Sealed NOT_FOUND; audit logs contain no tokens or PII |
| Logout/account switch races delayed response | Invalidate local session generation immediately; cleanup survives errors | **VERIFIED in F21:** `OfflineMeshManager.stop()` teardown wrapped in try-catch blocks |
| Server/database outage | Fail closed for reads; preserve online app behavior where available | **VERIFIED in B20:** Router-wide `OFFLINE_MESH_ENABLED` gate fails closed |

---

## 6. Metadata Minimization

Peers observe connection/routing details, packet size, timing, version, coarse operation, stable origin/destination tokens, and request IDs. They never observe patient/hospital references, bearer JWTs, staff identity, or record contents.

Stable IDs make correlation possible. The feature is **not anonymous**. `MeshSettingsTile` copy was corrected (F20) to remove the false "anonymously" claim and accurately state: *"Help relay encrypted hospital directory requests for nearby community members."*

---

## 7. Storage, Deletion and Logout

| Location | Permitted Contents | Retention and Cleanup |
| --- | --- | --- |
| Origin memory | Current authorized result, minimal rendering metadata | Cleared on logout/stop; decrypted results tagged `source: 'mesh'` |
| Origin/relay SQLite | Ciphertext and bounded route/dedupe metadata | No plaintext records or JWTs; expired packets deleted on queue sweeps |
| Origin secure storage | Ed25519/X25519 private keys, enrollment data | Platform secure storage; cleared via `DeviceIdentity.clearIdentity()` on stop |
| SharedPreferences | Participation consent and config cache | No medical cache; continuous 24-hr lease check enforced |
| Server mesh collection | Replay digest, origin binding, restricted audit correlation, sealed response | 900-second TTL index; responses expire at `exp` regardless of row retention |
| Logs/notifications | Bounded operational codes and restricted correlation IDs | No record content, target reference, token, keys, or stack traces logged |

---

## 8. Open Release Gates

| Decision | Required Owner / Input | Status |
| --- | --- | --- |
| Hospital directory field classification (`registeredPhone`) | Existing API/data owner | UI modal suppresses `registeredPhone`; backend route review pending |
| Patient-specific authorization/consent source | Existing application owner | All patient requests denied |
| Host toolchain verification | CI / DevOps | Dart CLI not installed on host; tests written awaiting Flutter SDK |
| Physical Android three-device scenario (M05) | QA / Mobile owner | Pending hardware provisioning |
