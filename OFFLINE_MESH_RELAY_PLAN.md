# Read-only hospital data over offline mesh

**Documentation baseline:** 24 October 2026.

**Implementation status:** Resumed implementation in progress. Build blockers resolved; backend security integration suite (`meshReadOnly.test.js`) and cross-language vector suite (`meshVectors.test.js`) implemented and passing (39 tests total); mobile transport/lifecycle hardening complete. Production mesh remains disabled (`OFFLINE_MESH_ENABLED=false`).

This plan replaces the earlier patient-profile relay proposal. The repository already contains a Flutter application, Express/Mongoose backend, and an initial mesh implementation. The design extends those components, preserves the online hospital workflows, and denies every hospital-data mutation through mesh.

---

## 1. Document Map

| Document | Purpose |
| --- | --- |
| [Implementation handoff](docs/offline-mesh/IMPLEMENTATION_HANDOFF.md) | Exact code work performed, changed files, defect resolutions, test results (39 passing tests), and remaining release gates |
| [Repository inventory and operation eligibility](docs/offline-mesh/REPOSITORY_INVENTORY.md) | Actual endpoints, authorization, consent findings, reusable components, and justified gaps |
| [Architecture and protocol](docs/offline-mesh/ARCHITECTURE_AND_PROTOCOL.md) | Trust boundaries, v2 packet format, dispatch, timing, duplicate handling, and feature isolation |
| [Security and privacy](docs/offline-mesh/SECURITY_AND_PRIVACY.md) | Threat model, end-to-end confidentiality, authorization, consent, lifecycle, audit, and verified controls |
| [Tests and acceptance](docs/offline-mesh/TEST_AND_ACCEPTANCE_PLAN.md) | Verification results (B01–B26, C01–C08), regression checklist, physical-device scenarios, and acceptance traceability |
| [Rollout and rollback](docs/offline-mesh/ROLLOUT_AND_ROLLBACK.md) | Component change impact, compatibility, controlled rollout, disablement, rollback, and release gates |

---

## 2. Non-Negotiable Scope

1. **Closed Read Operation:** Only `READ_HOSPITAL` is permitted in the feature queue and server dispatcher. A GET method alone does not establish read-only behavior.
2. **Zero Mutations:** Mesh must never create, update, delete, submit, or otherwise modify hospital or patient records. Transport enrollment, revocation, replay bookkeeping, and access audit records are separate control-plane writes, not hospital business operations.
3. **Origin Authorization:** The server must authenticate and authorize the **originating user** when it processes the request. A trusted peer or gateway cannot grant permission to read data.
4. **End-to-End Encryption:** Intermediate devices, including the internet-connected gateway, forward ciphertext only. They never decrypt protected request details, bearer credentials, or returned records.
5. **Architectural Reuse:** Existing APIs, data models, authentication issuer, business rules, networking, crypto libraries, storage, and Provider state management remain the foundation. No new database, auth service, general-purpose proxy, or duplicate hospital business logic is introduced.
6. **Preserve Online Workflows:** The online application must continue working when mesh is disabled, unsupported, or unavailable. Failures and mock/demo records must not be presented as verified mesh data.

---

## 3. Repository Findings That Constrain the Design

The existing `GET /api/citizens/:id` and citizen search are public. No server-side policy was found that authorizes a particular hospital employee to read a particular patient's record or checks patient data-sharing consent. The organ-pledge verification endpoint verifies a donation pledge; it does not authorize medical-record disclosure. An NFC token or a UI PIN setting does not fill this gap.

Consequently, **patient profiles, medical history, prescriptions, and report contents remain excluded from mesh**. Their presence in an existing API response does not make them eligible. They can only be reconsidered when an existing enforceable access/consent policy is identified, or a separately scoped change establishes one.

The only operation in the implementation allowlist is `READ_HOSPITAL`, mapping to the existing `GET /api/hospitals/:hospitalId` directory read. It is a **candidate scope**, not a released or clinically approved feature. The current hospital projection also includes `registeredPhone` (used for hospital staff login OTP); the UI modal (`_HospitalDetailModal`) suppresses this field and displays only public `phone`. Backend projection review remains an open policy gate before production enablement. Hospital lists, blood requests, PHCs, blood-bank data, and citizen self-service health reports have not been admitted to this allowlist.

`GET /api/citizens/:id/nfc-token` can create or update NFC card records. It is expressly forbidden through mesh despite being a GET endpoint.

---

## 4. Delivery Stages and Freshness

The architecture distinguishes four events: request creation on the offline origin, acceptance by a relay, server receipt and authorization, and verified delivery to the origin. The relay's acceptance is not server authorization. Successful delivery is not proof that data is current.

The implementation enforces a 120-second maximum request lifetime, up to 30 seconds of future clock skew, and responses expiring no later than the request or origin JWT (`min(request.exp, originJWT.exp)`). Responses include server receipt, authorization, and snapshot timestamps. A continuous 24-hour runtime configuration lease check (`MeshConfig.isRuntimeLeaseValid`) prevents stale operation in long-lived backgrounded apps. The UI displays clear provenance ("Verified Offline Mesh Snapshot" vs "Live Online Directory Data"), snapshot time, and delivery time.

---

## 5. Working-Tree State & Test Verification

All changes in the working tree are preserved and tracked:
- **Build Blocker F01:** Resolved in `lib/main.dart` and `lib/services/api_service.dart`.
- **Backend Security Suite (B01–B26):** Implemented in `backend/src/meshReadOnly.test.js`. 26 subtests verify strict read-only enforcement, JWT origin verification, principal checks, replay protection, rate limiting, and zero database mutations. **26 PASS, 0 FAIL.**
- **Cross-Language Crypto Suite (C01–C08):** Implemented in `backend/src/meshVectors.test.js`, with vectors in `test/vectors/mesh_v2_vectors.json` and Dart equivalents in `test/offline_mesh/`. **8 PASS, 0 FAIL.**
- **Baseline Suite:** `backend/src/offlineMesh.test.js` updated to v2. **4 PASS, 0 FAIL.**
- **Total Backend Verification:** `npm test` runs 39 tests with **39 PASS, 0 FAIL**.
- **Mobile Transport & Lifecycle Hardening:** Completed for F04 (cache keys), F05 (UI detail modal & uncoupling), F06 (progress callbacks), F08 (runtime lease & provenance), F09 (metered connection checks), F10 (peer connection triggers), F16 (legacy API cleanup), F20 (settings copy), and F21 (fail-safe teardown).
- **Host Toolchain Status:** Flutter/Dart command-line executables are not present on the host environment PATH; mobile unit tests are prepared in `test/offline_mesh/` awaiting a Flutter-provisioned environment.

---

## 6. Decisions and Release Gates

| Decision | Current Disposition |
| --- | --- |
| Patient-data relay | Denied at all layers until specific server authorization and consent can be enforced |
| Candidate read | One hospital directory entry (`READ_HOSPITAL`); UI suppresses `registeredPhone`; backend projection review pending |
| Existing online endpoints | Preserved names, request/response contracts, and existing business behavior |
| Crypto and persistence | Reused existing libraries (`cryptography` in Dart, Node `crypto`); cross-language vectors verified |
| Protocol version | v2 protocol with canonical JSON, AAD binding, and sealed errors; legacy routes return 410 |
| Default enablement | Mobile build flag defaults off (`false`); server requires explicit `OFFLINE_MESH_ENABLED=true` |
| Production deployment | Blocked pending toolchain test execution, physical Android validation, and operational sign-off |
