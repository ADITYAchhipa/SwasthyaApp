# SwasthyaTap — Offline Mesh Relay for Medical Data Retrieval

**Implementation plan, adapted to this repository (Flutter 3.12 app + Express/Mongoose backend on Vercel).**
Scope: **Hospital portal first** (doctor/ward staff retrieving a patient record with no internet), reusing the same
infrastructure for the citizen NFC-scan flow afterwards.

Status: PLAN ONLY — no code written yet. Everything below is additive; the existing online path is untouched.

---

## 0. What the codebase actually is (Phase 1 result)

This is the inspection required by §31/§41 of the brief. **The generic spec was written for an unknown stack;
this section is the ground truth that every later section is bent to fit.**

### 0.1 Mobile

| Concern | Reality in this repo |
|---|---|
| Framework | Flutter, Dart SDK `^3.12.2` (`pubspec.yaml`) |
| State management | `provider` — one god-object `SwasthyaTapProvider extends ChangeNotifier` (`lib/providers/swasthya_tap_provider.dart`, 1200 lines) wired in `lib/main.dart` via a single `ChangeNotifierProvider` |
| Networking | `http` package, all calls funnelled through `ApiService` (`lib/services/api_service.dart`) — **static** methods, static `_authToken`, `_headers` getter, per-call `.timeout(...)`, `try/catch` → mock/offline fallback |
| Base URL | `ApiService.baseUrl` — hardcoded `useProduction = true` → `https://swasthyabackend.vercel.app/api` |
| Session storage | `AuthStorage` (`lib/services/auth_storage.dart`) over `shared_preferences`: `auth_token`, `citizen_id`, `hospital_id`, `hospital_name`, `auth_role`. **No secure storage exists today.** |
| Reachability | `ApiService.isServerReachable()` → `GET /api/ping`, 3s timeout. Already a real reachability probe, not a Wi-Fi flag. |
| Crypto available | `crypto: ^3.0.7` (SHA-256/HMAC only — **no asymmetric primitives**) |
| Local persistence | `shared_preferences` only. No sqflite, no Hive, no Drift. |
| Existing "offline" notion | `SwasthyaTapProvider._isInternetAvailable` + `setInternetAvailability()` + `simulateNfcTap(payload, internetAvailable)` — a *demo* toggle that shows a reduced NDEF-only profile when offline. This is the UX hook the mesh replaces/upgrades. |
| Permissions | `permission_handler: ^11.3.1` already a dependency; manifest has INTERNET, NFC, CAMERA, FINE/COARSE_LOCATION |
| Logging | `debugPrint('methodName error: $e')` convention throughout `ApiService` |
| Tests | `test/` — 3 widget tests (`nfc_writer_test.dart`, `profile_setup_test.dart`, `widget_test.dart`), `flutter_test` only |

### 0.2 Hospital retrieval path (the thing we are extending)

```
hospital_login_screen.dart
  → ApiService.verifyHospital()  → JWT { hospitalId, personnelId, hospitalName }
  → ApiService.setHospitalToken() → AuthStorage.saveHospitalSession()

hospital_dashboard.dart:42  _searchPatient(provider)
  → ApiService.getCitizen(slug)                  ← THE ONLINE FETCH
  → provider.profiles[] cache update
  → setState(_searchedProfile)
  → _navigateToScreen(...) / ScannedProfileScreen

hospital_dashboard.dart:898  (prescription / report flow) → same ApiService.getCitizen(slug)
nfc_card_reader_screen.dart:157 _handleSuccess(profileId) → ScannedProfileScreen
scanned_profile_screen.dart:33 → ApiService.getCitizen(widget.profileId)
```

`ApiService.getCitizen()` today **silently falls back to `_mockCitizenJson()`** on any failure. That is the single
most important existing behaviour to be careful with: offline currently produces *fake* data, not an error. The mesh
path must be inserted **before** that mock fallback, and the mock fallback must be demoted (see §3.3).

### 0.3 Backend

| Concern | Reality in this repo |
|---|---|
| Framework | Express 4 (`backend/src/index.js`), CommonJS |
| Deploy | **Vercel serverless** (`backend/vercel.json`, `if (!process.env.VERCEL) app.listen(...)`) — no long-lived process, **no background workers, no websockets, no in-memory queues** |
| DB | MongoDB via Mongoose 8; connection warm-up middleware `connectDb()` runs before every non-health route |
| Auth | `backend/src/middleware/auth.js` → `authenticate` / `optionalAuth`, JWT `HS256` with `process.env.JWT_SECRET`. Payloads: citizen `{ citizenId, phoneNumber }`, hospital `{ hospitalId, personnelId, hospitalName }`. Two hardcoded dev bypass tokens: `mock_hospital_token`, `offline_token`. |
| Structure | `routes/` (fat — controller + business logic inline), `models/`, `middleware/`, `seed/`. **There is no `services/` or `repository/` layer.** |
| Medical data source | `routes/citizens.js` → `formatCitizen(citizen)` helper + `GET /api/citizens/:id` (public read; also resolves 64-char NFC `rawToken` via `NfcCard`) |
| Env vars | `MONGO_URI, JWT_SECRET, CLOUDINARY_*, TWILIO_*, SHOW_DEV_OTP, PORT, NODE_ENV, VERCEL` |
| Logging | `console.log`/`console.error` with emoji prefixes, `[timestamp] METHOD /url` request logger |
| Tests | none |

### 0.4 Consequences for the spec (deviations, and why)

These are deliberate departures from the brief. Each is forced by the stack above.

1. **No `offlineMeshController/Service/Repository/QueueService` split on the backend.**
   The project convention is fat `routes/*.js` + `models/*.js`. We add `routes/offlineMesh.js` (thin) plus a
   **new** `backend/src/services/` folder holding only the crypto + validation logic — that split is justified
   because it is the part that needs unit tests, but we do not introduce a repository layer that exists nowhere else.

2. **No async job queue on the backend.** Vercel serverless kills the process after the response. So
   `POST /api/offline-mesh/request` **processes the request synchronously and returns the encrypted response in the
   same HTTP response** (fast path). `GET /api/offline-mesh/response/:requestId` exists only as the retry/poll
   fallback for a gateway that lost the HTTP response mid-flight. Statuses `PROCESSING`/`RESPONSE_READY` still exist
   in the model but are transient.

3. **JWT cannot be the offline auth mechanism.** An offline hospital device may hold an expired token and cannot
   refresh. Authentication of an offline request is therefore **Ed25519 device-signature over a server-registered
   public key**, bound at registration time (while online) to the existing `hospitalId`/`citizenId` from the
   existing JWT. We reuse the existing auth system to *establish* device identity; we do not build a second auth system.

4. **`crypto: ^3.0.7` is not enough** — it has no X25519/Ed25519/AEAD. New dependency `cryptography` is unavoidable.

5. **`shared_preferences` is not enough** for the relay cache / queue / route table (needs indexed lookup by
   `request_id`, TTL sweeps, and survival across restarts). New dependency `sqflite`.

6. **iOS mesh transport is out of scope for v1** (see §11.3 and Known Limitations). Android-only, behind the
   feature flag, with a Loopback/Simulated transport so the feature is developable and testable on emulators.

---

## 1. Architecture as it lands in this repo

```
┌─ Hospital device (OFFLINE) ─────────────┐
│ hospital_dashboard._searchPatient()     │
│   └ MedicalDataGateway.fetchCitizen()   │  ← NEW seam, the only call-site change
│       ├ online?  → ApiService.getCitizen()      (UNCHANGED existing path)
│       └ offline? → OfflineMeshManager.request() (NEW)
│            ├ DeviceIdentity   (Ed25519 + X25519, flutter_secure_storage)
│            ├ CryptoManager    (E2E seal to backend pubkey)
│            ├ OfflinePacket    (versioned, signed, TTL'd)
│            ├ MeshQueue/RelayCache/RouteManager (sqflite)
│            └ MeshTransport ──┐
└──────────────────────────────┼──────────┘
                               │ Nearby Connections (P2P_CLUSTER) / BLE
                    ┌──────────▼───────────┐
                    │ Relay device (any    │  RelayManager: verify sig → dedupe →
                    │ SwasthyaTap install, │  TTL-- → route entry → forward
                    │ offline)             │  (cannot decrypt L2)
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │ Gateway device       │  NetworkManager.isInternetAvailable()
                    │ (has internet)       │  → ApiService.submitMeshPacket()
                    └──────────┬───────────┘
                               │ HTTPS
        ┌──────────────────────▼─────────────────────────┐
        │ backend/src/routes/offlineMesh.js              │
        │  validate → verify Ed25519 → replay check      │
        │  → open sealed payload (X25519+AES-256-GCM)    │
        │  → REUSE Citizen.findOne + formatCitizen()     │
        │  → seal response to requester's X25519 pubkey  │
        │  → persist metadata only (OfflineMeshRequest)  │
        └──────────────────────┬─────────────────────────┘
                               │ encrypted response (same HTTP response)
                    reverse path via RouteManager: Gateway → Relay → Hospital device
                               │
                    CryptoManager.open() → MedicalProfile → existing UI
```

**Layering:** L1 = per-hop session encryption (relay *can* decrypt, sees only routing metadata).
L2 = end-to-end seal between requesting device and backend (relay *cannot* decrypt, ever).

---

## 2. New dependencies

### 2.1 `pubspec.yaml` (mobile)

```yaml
dependencies:
  # ── offline mesh ──
  cryptography: ^2.7.0            # X25519, Ed25519, AES-256-GCM, ChaCha20-Poly1305, HKDF (pure Dart)
  cryptography_flutter: ^2.3.2    # native-accelerated impls where available
  flutter_secure_storage: ^9.2.2  # Android Keystore / iOS Keychain backed
  sqflite: ^2.3.3                 # relay cache, packet queue, route table
  path: ^1.9.0                    # db path join (transitive, declare explicitly)
  connectivity_plus: ^6.0.5       # transport/interface state (NOT used as proof of internet)
  nearby_connections: ^4.2.0      # Android Nearby Connections transport
  uuid: ^4.5.1                    # request_id (v4, crypto-secure)
```

Already present and reused: `crypto` (SHA-256 for id hashes), `permission_handler`, `http`, `shared_preferences`, `provider`.

### 2.2 Backend

**None.** Node's built-in `crypto` covers everything:
`crypto.generateKeyPairSync('x25519'|'ed25519')`, `crypto.diffieHellman()`, `crypto.hkdfSync()`,
`crypto.createCipheriv('aes-256-gcm')`, `crypto.verify(null, msg, ed25519PubKey, sig)`, `crypto.timingSafeEqual()`.
Test runner: built-in `node:test` (add script only, no dependency).

---

## 3. Mobile implementation

### 3.1 File map (all new unless marked)

```
lib/services/offline_mesh/
  mesh_config.dart              # feature flag + all tunables, remote-overridable
  mesh_logger.dart              # structured, allow-listed fields only
  device_identity.dart          # Ed25519 + X25519 keypairs, secure storage, deviceId
  crypto_manager.dart           # seal/open (L2), session keys (L1), sign/verify
  offline_packet.dart           # OfflinePacket model + canonical serialization
  network_manager.dart          # isInternetAvailable / isMetered / transport availability
  store/
    mesh_database.dart          # sqflite open + migrations
    relay_cache.dart            # seen_requests
    mesh_queue.dart             # outbound packet queue
    route_manager.dart          # reverse-path table
  transport/
    mesh_transport.dart         # abstract interface + MeshPeer + events
    nearby_transport.dart       # Android Nearby Connections impl
    loopback_transport.dart     # in-process, for unit/integration tests
    simulated_transport.dart    # dev-only LAN multicast, lets 2 emulators mesh
  peer_manager.dart             # discovery, handshake, scoring, selection
  relay_manager.dart            # receive → validate → dedupe → forward/gateway
  offline_request_manager.dart  # create + track own requests
  offline_response_manager.dart # match responses to pending requests, decrypt
  offline_mesh_manager.dart     # public facade / orchestrator + lifecycle

lib/services/medical_data_gateway.dart   # THE SEAM: online-first, mesh-fallback
lib/providers/offline_mesh_provider.dart # ChangeNotifier for UI state machine
lib/widgets/offline_relay_progress.dart  # the §29 UI states as a bottom sheet
lib/screens/settings/mesh_settings_tile.dart # §23 consent toggle
```

**Modified files:**

| File | Change |
|---|---|
| `lib/main.dart` | `ChangeNotifierProvider` → `MultiProvider` adding `OfflineMeshProvider`; `await OfflineMeshManager.instance.bootstrap()` after `ensureInitialized()` |
| `lib/services/api_service.dart` | Add mesh HTTP methods (§4.6). Add `getCitizenOnlineOnly()` (no mock fallback) used by the gateway. **Existing `getCitizen()` signature/behaviour untouched.** |
| `lib/screens/hospital_portal/hospital_dashboard.dart` | `_searchPatient()` (line 42) and the inline fetch at line 898 → `MedicalDataGateway.fetchCitizen(...)`; render mesh progress sheet |
| `lib/screens/hospital_portal/hospital_login_screen.dart` | After successful `verifyHospital`, fire-and-forget `OfflineMeshManager.registerDeviceIfNeeded()` (needs internet — this is the enrolment moment) |
| `lib/screens/citizen_portal/scanned_profile_screen.dart` | `_profileFuture` → `MedicalDataGateway.fetchCitizen(...)` (phase 2 — same seam, no new logic) |
| `lib/screens/splash_screen.dart` | Restore mesh identity alongside `ApiService.init()`; start relay service if consent ON |
| `android/app/src/main/AndroidManifest.xml` | Permissions (§7) |
| `pubspec.yaml` | Dependencies (§2.1) |
| `test/` | New `test/offline_mesh/**` (§8) |

### 3.2 `MeshConfig` (§30 feature flags)

```dart
class MeshConfig {
  static const bool kEnabledAtBuild = true;        // compile-time kill switch
  static bool enabled = false;                     // remote + consent gated, default OFF
  static int  maxTtl = 8;
  static Duration requestTimeout = const Duration(seconds: 120);
  static int  maxPacketSizeBytes = 128 * 1024;
  static int  maxRetries = 3;
  static const List<Duration> retryDelays = [Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30)];
  static int  maxForwardAttemptsPerPacket = 3;
  static Duration clockSkewTolerance = const Duration(minutes: 5);
  static Duration routeTtl = const Duration(minutes: 5);
  static Duration relayCacheRetention = const Duration(minutes: 30);
  static Duration maxScanDuration = const Duration(seconds: 90);
  static bool allowMeteredGatewayUpload = false;   // §24
}
```

Loaded in this precedence: build const → `GET /api/offline-mesh/config` cached in `shared_preferences`
(key `mesh_config_cache`, refreshed opportunistically whenever the app *is* online) → user consent toggle.
`enabled == false` ⇒ `MedicalDataGateway` degrades to exactly today's behaviour.

### 3.3 `MedicalDataGateway` — the only behavioural seam

```dart
enum MedicalFetchSource { online, mesh, localCache }

class MedicalFetchResult {
  final MedicalProfile? profile;
  final MedicalFetchSource? source;
  final MeshFailure? failure;      // §27 enum
}

class MedicalDataGateway {
  static Future<MedicalFetchResult> fetchCitizen(
    String idOrToken, {
    void Function(MeshUiState)? onProgress,   // drives the §29 UI
  }) async {
    // 1. Online path — byte-for-byte the existing behaviour
    if (await NetworkManager.instance.isInternetAvailable()) {
      final p = await ApiService.getCitizenOnlineOnly(idOrToken);
      if (p != null) return MedicalFetchResult.online(p);
    }
    // 2. Mesh path — only if enabled + consented + transport available
    if (MeshConfig.enabled && await OfflineMeshManager.instance.isUsable()) {
      return OfflineMeshManager.instance.requestMedicalData(idOrToken, onProgress: onProgress);
    }
    // 3. Existing fallback preserved (mock/local cache) so nothing regresses
    return MedicalFetchResult.localCache(await ApiService.getCitizen(idOrToken));
  }
}
```

> **Flagged concern (stated, then built as asked):** step 3 preserves `ApiService.getCitizen()`'s current
> silent mock-data fallback purely to satisfy "do not break existing behaviour". Showing fabricated blood
> group / allergies to a doctor is dangerous. Recommendation, to decide separately from this feature:
> make `MedicalFetchSource.localCache` render a prominent "UNVERIFIED — demo data" banner in
> `ScannedProfileScreen`, or drop the mock fallback for the hospital portal entirely. The plan below is
> written so either choice is a one-line change in `MedicalDataGateway`.

### 3.4 `DeviceIdentity` (§6, PHASE 2)

```dart
class DeviceIdentity {
  // Generated once, on first launch after mesh enrolment.
  //   signing : Ed25519 keypair  → packet signatures
  //   agreement: X25519 keypair  → E2E seal/open with backend
  //   deviceId : base64url(SHA-256(ed25519_pub))[0..32]   ← derived, NOT hardware-derived
  //   destinationToken: server-issued (HMAC(server_secret, deviceId)), opaque to relays
}
```

- Private keys: `FlutterSecureStorage` with
  `AndroidOptions(encryptedSharedPreferences: true)` (Keystore-wrapped) and
  `IOSOptions(accessibility: first_unlock_this_device_only)`.
- **Never** in `SharedPreferences`/`AuthStorage`, sqflite, JSON, or logs. Lint note added to `analysis_options.yaml` is not enforceable — covered by the §8 test `no_key_material_in_prefs_test.dart`.
- No IMEI / MAC / serial anywhere.
- Enrolment (`POST /api/offline-mesh/register-device`) requires the existing JWT ⇒ device binds to `hospitalId` or `citizenId`. A device that never enrolled online can never use the mesh — accepted and documented.

### 3.5 `OfflinePacket` (§7, PHASE 3)

```jsonc
{
  "v": 1,                          // packet_version
  "t": "MEDICAL_DATA_REQUEST",     // packet_type: REQUEST | RESPONSE | HANDSHAKE_INIT | HANDSHAKE_ACK | ACK
  "rid": "<uuid v4>",              // request_id
  "org": "<b64u sha256(ed25519_pub)>",  // origin_device_id_hash
  "dst": "<opaque destination_token>",
  "iat": 1787031600,               // created_at, unix seconds UTC
  "exp": 1787031720,               // expires_at
  "ttl": 8,
  "epk": "<b64u ephemeral X25519 pub>",  // for the L2 seal
  "pay": "<b64u ciphertext||tag>",       // encrypted_payload
  "sig": "<b64u ed25519 over canonical(v,t,rid,org,dst,iat,exp,epk,pay)>"
}
```

**`ttl` is deliberately excluded from the signed region** — it mutates at every hop, so signing it would break
verification. Loop protection does not depend on `ttl` integrity (a malicious relay inflating `ttl` is bounded by
`exp` and by each honest relay's dedupe cache). This is called out because the brief's §7 field list implies otherwise.

Cleartext payload (sealed into `pay`) — the *minimum* the backend needs:

```jsonc
{ "op":"FETCH_CITIZEN", "ref":"<profileId | 64-char nfc rawToken>",
  "req":{"role":"hospital","hospitalId":"HOSP001","personnelId":"P1"},
  "nonce":"<b64u 24 bytes>", "iat":1787031600 }
```

No name, blood group, ABHA, phone, diagnosis, or hospital *name* appears in any cleartext field. `dst` is opaque.

Serialization: **canonical JSON** (keys sorted, no whitespace, integers only for times) → UTF-8 → sign.
`PacketCodec.encode/decode` is the single place this is implemented; the signature test suite pins the byte layout.

### 3.6 `CryptoManager` (§5, PHASE 4)

| Purpose | Primitive |
|---|---|
| L2 seal device→backend | ephemeral X25519 → HKDF-SHA256(info=`"swasthyatap/mesh/v1/req"`) → **AES-256-GCM**, AAD = canonical header |
| L2 seal backend→device | ephemeral X25519 to device's registered X25519 pub, info=`".../resp"`, AES-256-GCM |
| Packet authenticity | **Ed25519** detached signature |
| L1 peer session | X25519 handshake → HKDF (info=`".../session"`, salt = both nonces) → **ChaCha20-Poly1305** |

No custom constructions, no ECB/CBC, no key reuse across L1/L2, nonces are 96-bit random per seal (never counters —
devices restart and would repeat counters).

### 3.7 Store (sqflite) — §8, §19, §20, PHASE 5

`mesh.db`, three tables, all values encrypted-at-rest-as-received (we store the ciphertext packet, never plaintext):

```sql
CREATE TABLE seen_requests (            -- relay cache, dedupe
  request_id TEXT PRIMARY KEY, packet_type TEXT, first_seen INTEGER,
  expires_at INTEGER, completed INTEGER DEFAULT 0);
CREATE INDEX idx_seen_exp ON seen_requests(expires_at);

CREATE TABLE mesh_queue (               -- outbound queue, survives restart
  id INTEGER PRIMARY KEY AUTOINCREMENT, request_id TEXT, packet_type TEXT,
  packet_blob TEXT NOT NULL,            -- encrypted packet JSON, no plaintext
  state TEXT,                           -- QUEUED|FORWARDING|FORWARDED|DELIVERED|EXPIRED|FAILED
  attempts INTEGER DEFAULT 0, forwarded_peers TEXT, next_attempt_at INTEGER, expires_at INTEGER);
CREATE INDEX idx_queue_state ON mesh_queue(state, next_attempt_at);

CREATE TABLE routes (                   -- reverse path
  request_id TEXT PRIMARY KEY, previous_peer TEXT, next_peer TEXT,
  hops INTEGER, expires_at INTEGER);
CREATE INDEX idx_routes_exp ON routes(expires_at);
```

`MeshDatabase.sweepExpired()` runs on app start, on every packet receipt, and on a 60s timer while the mesh
service is active. `routes` rows are deleted the moment a response is forwarded, or at `expires_at`.

### 3.8 `MeshTransport` abstraction (§11, PHASE 6–7)

```dart
abstract class MeshTransport {
  String get id;                                   // 'nearby' | 'loopback' | 'simulated'
  Future<bool> isAvailable();
  Future<void> startDiscovery({Duration? maxDuration});
  Future<void> stopDiscovery();
  Stream<MeshPeer> get onPeerDiscovered;
  Stream<MeshPeer> get onPeerLost;
  Future<bool> connectToPeer(String peerId);
  Future<void> disconnectPeer(String peerId);
  Future<bool> sendFrame(String peerId, Uint8List frame);   // L1-encrypted bytes
  Stream<MeshFrame> get onFrameReceived;
  Future<void> dispose();
}
```

`MeshPeer { peerId, transportId, lastSeen, rssi?, state, advertisedHasInternet, hopHint }`.

**No business logic in transports.** They move opaque bytes. `RelayManager` never imports `nearby_connections`.

- `NearbyTransport` — `nearby_connections` `Strategy.P2P_CLUSTER`, service id `in.swasthyatap.mesh.v1`.
  Advertise + discover simultaneously; endpoint name = `deviceId[0..8] + '|' + (hasInternet?'G':'R')` so §14
  gateway preference works before any connection. Payload via `sendBytesPayload` (chunk >32KB — enforced by
  `MeshConfig.maxPacketSizeBytes`).
- `LoopbackTransport` — two `MeshNode` instances in one Dart isolate, used by every integration test in §8.
- `SimulatedTransport` — dev builds only, UDP multicast on the LAN, so scenarios 3/4/6 can be exercised on
  emulators before physical-device testing (PHASE 19).

### 3.9 `PeerManager` — handshake + selection (§12, §14, PHASE 8)

Handshake (before any packet is accepted from a peer):

```
A → HANDSHAKE_INIT { deviceIdHash, ed25519_pub, x25519_pub, nonceA, iat, sig }
B → HANDSHAKE_ACK  { deviceIdHash, ed25519_pub, x25519_pub, nonceB, iat, sig }
both: sessionKey = HKDF(X25519(a,B) , salt = nonceA||nonceB, info = "swasthyatap/mesh/v1/session")
```
Both sides verify the peer's Ed25519 signature over its own handshake body and reject `|iat - now| > 5 min`.
Peer keys are **not** required to be server-registered (any SwasthyaTap install may relay); registration only
matters at the backend for the *originator*. Session keys live in memory only, dropped on disconnect.

Selection score (descending): confirmed-internet peer → advertised-gateway → RSSI → connection stability →
lowest hop hint → **not already in `forwarded_peers` for this request**. Cap: `maxForwardAttemptsPerPacket = 3`.
Never a blind broadcast to all peers.

### 3.10 `RelayManager` (§13, PHASE 10)

On every received REQUEST/RESPONSE frame, in order — each failure increments a counter and drops silently:

1. Decode; reject if size > `maxPacketSizeBytes` or `v` unknown.
2. Verify Ed25519 `sig` → else `INVALID_SIGNATURE`.
3. `exp < now` or `|iat - now| > 5min` → `REQUEST_EXPIRED`.
4. `relayCache.contains(rid)` → `DUPLICATE_REQUEST`, drop (this is what kills the A→B→C→A loop).
5. `ttl <= 0` → `TTL_EXCEEDED`.
6. Insert into `seen_requests`; for a REQUEST, insert `routes(rid, previous_peer=sender)`.
7. `ttl--`.
8. `NetworkManager.isInternetAvailable()`?
   - **yes** → gateway: `ApiService.submitMeshPacket()`; on 2xx, take the returned sealed response, verify, then
     route it back to `routes.previous_peer`. On failure → mark `FAILED`, re-queue for forwarding.
   - **no** → enqueue and forward to selected peers.
9. For a RESPONSE packet: look up `routes[rid]`. `previous_peer == self`? → hand to
   `OfflineResponseManager` (we are the originator). Else forward to `previous_peer` and delete the route row.

### 3.11 `OfflineRequestManager` / `OfflineResponseManager` (PHASE 9, 14)

- Create: `rid = uuid.v4()`, `iat = now`, `exp = now + requestTimeout`, `ttl = maxTtl`, fresh nonce, seal, sign, enqueue, start discovery.
- Track pending requests in memory + `mesh_queue`; a single `Completer` per `rid` resolved by the response manager.
- Timeout (`OFFLINE_REQUEST_TIMEOUT`, default 120s): mark `EXPIRED`, stop discovery, drop routes, emit `RESPONSE_TIMEOUT`.
- Retry: `maxRetries = 3` at 5s/15s/30s, bounded, only while `exp > now`.
- On response: verify backend Ed25519 signature (backend signing pubkey pinned at registration), check `rid` match,
  open the seal → `MedicalProfile` via the **existing** `ApiService.parseCitizen()` (already public at line 688) →
  only then render.

### 3.12 `NetworkManager` (§25)

```dart
Future<bool> isInternetAvailable();       // connectivity_plus says "not none" AND ApiService.isServerReachable()
                                          // cached 15s to avoid hammering /api/ping
Future<bool> isMeteredConnection();
Future<bool> isBluetoothAvailable();
Future<bool> isNearbyTransportAvailable(); // permissions + BT + location services
```
Wi-Fi-connected is never treated as internet — the existing `/api/ping` probe is the proof.

### 3.13 UI (§29, §23, PHASE 15–16)

`OfflineMeshProvider` exposes a `MeshUiState` enum consumed by `offline_relay_progress.dart` (a modal sheet
launched from `hospital_dashboard._searchPatient` when the gateway reports it went to mesh):

| State | Copy (goes through `TranslationService.t`) |
|---|---|
| `offline` | "You're offline" |
| `searching` | "Searching nearby SwasthyaTap devices…" |
| `relayFound` | "Secure relay found" |
| `sent` | "Request sent through a nearby device" |
| `awaiting` | "Retrieving medical information…" |
| `received` | "Medical information received securely" |
| `failed` | "Unable to retrieve information offline. Please connect to the internet." |

No peer ids, key material, hop counts, or packet internals shown. Consent tile (§23):
*"Allow SwasthyaTap to use nearby devices for offline data retrieval"* — **default OFF**, stored in
`shared_preferences` (`mesh_consent`), with a one-time explainer that the device may forward encrypted packets
for others. Relay participation is a separate sub-toggle from *using* the mesh for your own requests.

---

## 4. Backend implementation (PHASE 11–13)

### 4.1 New files

```
backend/src/models/MeshDevice.js
backend/src/models/OfflineMeshRequest.js
backend/src/routes/offlineMesh.js
backend/src/services/meshCrypto.js       # NEW folder — seal/open/verify, node:crypto only
backend/src/services/meshValidation.js   # structural + temporal + replay validation
```

**Modified:** `backend/src/index.js` — two lines:
```js
const offlineMeshRoutes = require('./routes/offlineMesh');
app.use('/api/offline-mesh', offlineMeshRoutes);
```

### 4.2 `MeshDevice` model

```js
{
  deviceId:   { type: String, required: true, unique: true, index: true }, // b64u sha256(ed25519 pub)
  signingPublicKey:   { type: String, required: true },   // base64 raw Ed25519
  agreementPublicKey: { type: String, required: true },   // base64 raw X25519
  ownerType:  { type: String, enum: ['hospital','citizen'], required: true },
  hospitalId: { type: String, index: true, sparse: true }, // from existing JWT
  citizenId:  { type: String, index: true, sparse: true },
  personnelId: String,
  destinationToken: { type: String, index: true },  // HMAC(MESH_SERVER_SECRET, deviceId)
  status:     { type: String, enum: ['active','revoked'], default: 'active' },
  lastSeenAt: Date,
}  // { timestamps: true }
```

### 4.3 `OfflineMeshRequest` model (§16) — **metadata only**

```js
{
  requestId: { type: String, required: true, unique: true, index: true },
  originDeviceId: { type: String, index: true },
  requestType: String,                      // 'MEDICAL_DATA_FETCH'
  createdAt: Number, expiresAt: Number,     // from the packet (unix sec)
  receivedAt: { type: Date, default: Date.now },
  status: { type: String, enum: ['RECEIVED_BY_GATEWAY','PROCESSING','RESPONSE_READY','DELIVERED','EXPIRED','FAILED','REJECTED'], default: 'RECEIVED_BY_GATEWAY', index: true },
  ttlOnArrival: Number,
  gatewayDeviceId: String,
  gatewayIp: String,                        // rate-limiting only
  targetRefHash: String,                    // sha256(profileId) — NEVER the id itself
  responseStatus: String,
  sealedResponse: String,                   // ciphertext, short-lived (see TTL index)
  completedAt: Date,
  rejectReason: String,
}
```

Indexes: `{ requestId: 1 }` unique (this is the replay guard — a second insert of the same `requestId` throws
E11000 and is answered idempotently), plus a **TTL index** `{ receivedAt: 1 }, { expireAfterSeconds: 900 }` so
ciphertext and metadata self-delete after 15 minutes. **No plaintext medical data is ever written to this collection.**

### 4.4 `meshCrypto.js`

```js
serverKeys()                    // loads MESH_SERVER_X25519_PRIVATE / MESH_SERVER_ED25519_PRIVATE from env
verifyPacketSignature(packet, signingPublicKeyB64)  // canonical bytes, crypto.verify(null, ...)
openSealed(epkB64, ciphertextB64, aadBytes)         // X25519 → hkdfSync → aes-256-gcm decrypt
sealForDevice(plainObj, deviceAgreementPubB64, aadBytes)  // ephemeral X25519 → aes-256-gcm
signResponse(canonicalBytes)                        // Ed25519
destinationToken(deviceId)                          // HMAC-SHA256(MESH_SERVER_SECRET, deviceId)
```

Canonical-JSON helper is shared byte-for-byte with the Dart `PacketCodec` — a golden-vector test file
(`test/offline_mesh/vectors.json`) is asserted by **both** suites so the two implementations cannot drift.

### 4.5 Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/offline-mesh/register-device` | `authenticate` (existing JWT) | Bind Ed25519+X25519 pubkeys → returns `{ deviceId, destinationToken, serverAgreementPublicKey, serverSigningPublicKey, config }`. Idempotent per deviceId. Rebinding to a different owner is rejected. |
| `POST` | `/api/offline-mesh/request` | `optionalAuth` | **Gateway upload.** Packet is self-authenticating; gateway identity is advisory only. Validates → processes → returns sealed response inline. |
| `GET` | `/api/offline-mesh/response/:requestId` | `optionalAuth` | Poll fallback if the gateway lost the inline response. Returns the same sealed blob (idempotent), 404 after TTL expiry. |
| `POST` | `/api/offline-mesh/response-ack` | `optionalAuth` | Origin device confirms delivery → status `DELIVERED`, `sealedResponse` cleared immediately. |
| `GET` | `/api/offline-mesh/status/:requestId` | `optionalAuth` | Metadata only: `{ status, receivedAt, completedAt }`. No medical data, no target ref. |
| `GET` | `/api/offline-mesh/config` | none | `{ enabled, maxTtl, requestTimeoutSeconds, maxPacketSizeKb, maxRetries }` — the remote kill switch. |
| `POST` | `/api/offline-mesh/register-gateway` | `authenticate` | Optional (§17). Marks a device as a willing gateway + records `lastSeenAt`. Deferred to v1.1 — nothing in the flow depends on it. |

### 4.6 `POST /api/offline-mesh/request` — exact order of operations

```
1.  MESH: if OFFLINE_MESH_ENABLED !== 'true' → 503 { code: 'MESH_DISABLED' }
2.  Body size guard (express.json limit) + packet.v === 1 + required fields present
3.  now = Math.floor(Date.now()/1000)
    reject if packet.exp <= now                       → 410 REQUEST_EXPIRED
    reject if Math.abs(packet.iat - now) > 300        → 400 CLOCK_SKEW
    reject if packet.ttl < 0                          → 400 TTL_EXCEEDED
4.  device = MeshDevice.findOne({ deviceId: packet.org, status: 'active' })
    → 401 UNKNOWN_DEVICE if missing/revoked
5.  verifyPacketSignature(packet, device.signingPublicKey)  → 401 INVALID_SIGNATURE
6.  timingSafeEqual(packet.dst, destinationToken(device.deviceId)) → 400 BAD_DESTINATION
7.  OfflineMeshRequest.create({ requestId, ... })      // unique index = replay guard
    on E11000: if an existing row has sealedResponse → return it (idempotent, gateway retry)
               else → 409 DUPLICATE_REQUEST
8.  payload = openSealed(packet.epk, packet.pay, aad = canonicalHeader(packet))  → 400 DECRYPTION_FAILED
9.  Authorization (reuse existing rules from routes/citizens.js):
       ownerType==='hospital' → allowed (mirrors the existing public GET /api/citizens/:id read)
       ownerType==='citizen'  → payload.ref must resolve to that citizenId  → 403
10. Resolve the patient with the SAME logic as GET /api/citizens/:id:
       Citizen.findOne({ profileId: ref })
       || NfcCard.findOne({ rawToken: ref }) → Citizen.findById(card.patientId)
    → not found: still return a *sealed* NOT_FOUND response (never leak existence in cleartext)
11. data = formatCitizen(citizen)                     // REUSED, unmodified
12. sealed = sealForDevice({ rid, ok:true, citizen:data, iat, exp: iat+120 }, device.agreementPublicKey, aad)
13. sign the response header with the server Ed25519 key
14. persist status RESPONSE_READY + sealedResponse; log requestId/status only
15. 200 { success:true, response: { v, t:'MEDICAL_DATA_RESPONSE', rid, iat, exp, epk, pay, sig } }
```

Rate limiting: per-`gatewayIp` and per-`originDeviceId` counters (a small `meshRateLimit` collection or an
in-document counter — chosen because Vercel has no shared in-memory store). Default 60 requests/device/hour.

### 4.7 Environment variables

```
OFFLINE_MESH_ENABLED=true
OFFLINE_MESH_MAX_TTL=8
OFFLINE_MESH_REQUEST_TIMEOUT_SECONDS=120
OFFLINE_MESH_MAX_PACKET_SIZE_KB=128
OFFLINE_MESH_MAX_RETRIES=3
OFFLINE_MESH_CLOCK_SKEW_SECONDS=300
OFFLINE_MESH_RATE_LIMIT_PER_HOUR=60
MESH_SERVER_SECRET=<32+ random bytes, base64>            # destination token HMAC
MESH_SERVER_X25519_PRIVATE=<base64 PKCS8>                # response sealing
MESH_SERVER_ED25519_PRIVATE=<base64 PKCS8>               # response signing
```
Generation helper to ship: `backend/src/seed/generate_mesh_keys.js` (prints all three, writes nothing).
**Key rotation:** `register-device` returns the current server pubkeys; devices cache them and re-register when a
sealed response fails to verify. Rotation therefore costs one online re-enrolment per device.

---

## 5. Database migrations

Mongoose creates collections lazily — no migration files, matching the existing project (there are none). Required
one-time index creation is handled by the schema definitions plus:

```
backend/src/seed/mesh_indexes.js   # ensureIndexes() for MeshDevice + OfflineMeshRequest (incl. the 900s TTL index)
```
Run once per environment: `node src/seed/mesh_indexes.js`. Existing collections are untouched.

---

## 6. Security & privacy (§2, §21, §22, §34, §35)

- **Relay sees:** `v, t, rid, org(hash), dst(opaque), iat, exp, ttl, epk, pay(ciphertext), sig`. Nothing else.
- **Relay cannot see:** patient id/token, name, blood group, allergies, medications, DNR, organ pledge,
  insurance, contacts, prescriptions, reports, hospital name, personnel id.
- `dst = HMAC(MESH_SERVER_SECRET, deviceId)` — stable per device, opaque to peers, not linkable to a person
  without the server secret.
- `targetRefHash = sha256(profileId)` is the only reference stored server-side in the mesh collection.
- Replay defence is the **conjunction** required by §35: `requestId` uniqueness **and** Ed25519 signature **and**
  `iat` skew window **and** `exp` **and** TTL **and** the on-device relay cache **and** device registration status.
  None of these alone is trusted.
- **Logging allow-list** (`MeshLogger`): `requestId, packetType, ttl, status, peerIdHash(first 8 chars),
  transportId, errorCode, durationMs, hopCount`. The logger takes a `Map<String,Object>` and **drops any key not
  on the allow-list** rather than trusting call sites. Backend equivalent: `console.log('[mesh]', {requestId, status, code})`.
- No `debugPrint` of packets, payloads, keys, or profiles anywhere in `lib/services/offline_mesh/**` — asserted by
  a grep-based test (§8).

---

## 7. Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<!-- Nearby Connections / BLE mesh -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
                 android:usesPermissionFlags="neverForLocation" tools:targetApi="s" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
                 android:usesPermissionFlags="neverForLocation" tools:targetApi="tiramisu" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```
`ACCESS_FINE_LOCATION` is already declared (needed by Nearby on API < 31). Add `xmlns:tools` to `<manifest>`.
Runtime requests go through the existing `permission_handler`, requested **only** when the user first triggers an
offline retrieval or enables relay participation — never at startup.

### iOS (`ios/Runner/Info.plist`) — only when the iOS transport lands

```
NSBluetoothAlwaysUsageDescription
NSLocalNetworkUsageDescription
NSBonjourServices = _swasthyatap-mesh._tcp
UIBackgroundModes: bluetooth-central, bluetooth-peripheral
```

---

## 8. Testing (§33, §34, PHASE 17)

### Dart unit tests — `test/offline_mesh/`

| File | Covers |
|---|---|
| `packet_codec_test.dart` | canonical serialization, golden vectors, unknown-version reject, oversize reject |
| `crypto_manager_test.dart` | seal/open round trip, wrong key fails, tampered ciphertext fails (GCM tag), tampered header fails (AAD), sign/verify, nonce uniqueness |
| `device_identity_test.dart` | keygen once, deviceId derivation stable, keys absent from SharedPreferences |
| `relay_cache_test.dart` | duplicate detection, persistence across "restart" (re-open db), expiry sweep |
| `ttl_test.dart` | decrement, `ttl<=0` drop, MAX_TTL config |
| `expiry_replay_test.dart` | `exp` in past → drop; `iat` ±6 min → drop; ±4 min → accept |
| `route_manager_test.dart` | previous-hop recording, reverse lookup, expiry deletion |
| `mesh_queue_test.dart` | state machine, retry backoff schedule, attempt cap |
| `peer_selection_test.dart` | gateway-first ordering, no re-forward to a used peer, 3-peer cap |
| `mesh_logger_test.dart` | non-allow-listed keys are dropped |
| `no_plaintext_logs_test.dart` | grep `lib/services/offline_mesh/**` for `print(`/`debugPrint(` outside `MeshLogger` |

### Dart integration tests — `test/offline_mesh/integration/` (all over `LoopbackTransport` + a fake backend)

1. Device online → mesh code never runs, `ApiService.getCitizen` called exactly once.
2. Offline, zero peers → `NO_NEARBY_DEVICES` after timeout, discovery stopped, queue `EXPIRED`.
3. A offline, B offline, C online → success, 2 hops, response returns via C→B→A.
4. A, B, C all offline → timeout, no crash, all routes swept.
5. Duplicate packet delivered twice → second dropped, `duplicate_packets_dropped == 1`.
6. Loop A→B→C→A → A drops its own `rid` on re-entry; no infinite forwarding.
7. Expired request injected → dropped at first honest hop.
8. Invalid signature → dropped, `invalid_packets_dropped == 1`, never uploaded.
9. **Malicious relay:** relay holds ciphertext + its own keys, attempts `open()` → asserts failure and asserts
   the ciphertext bytes contain no substring of any plaintext field.
10. Gateway loses internet mid-upload → falls back to forwarding, request still completes via another gateway.
11. Relay killed and restarted mid-forward → queue reloaded from sqflite, forwarding resumes, no duplicate delivery.
12. Response returns through the exact reverse route; origin decrypts and yields a `MedicalProfile` equal to the fixture.

### Backend tests — `backend/src/**/*.test.js` via `node --test`

`"test": "node --test src"` added to `backend/package.json` (no new dependency).
Covers: signature verification, replay `E11000` idempotency, expiry/skew rejection, unknown/revoked device,
destination-token mismatch, `NOT_FOUND` returned sealed (not cleartext), `formatCitizen` reuse produces the same
shape as `GET /api/citizens/:id`, and **an assertion that no document in `offline_mesh_requests` contains any
field from the citizen fixture**.

### Development-mode fixture (§38)

`OFFLINE_MESH_MOCK_PAYLOAD=true` on the backend makes `/api/offline-mesh/request` seal
`{ bloodGroup:"O+", diagnosis:"TEST_ONLY", prescription:"MOCK_DATA" }` instead of touching `Citizen`.
All mesh bring-up (PHASE 6–14) is done against this, before the real data path is switched on.

---

## 9. Observability (§39)

Counters (device-side, in `shared_preferences` under `mesh_metrics`, uploaded opportunistically when online via a
`POST /api/offline-mesh/metrics` in v1.1; backend-side just `console.log('[mesh]', {...})` picked up by Vercel logs):

`offline_requests_created, offline_requests_relayed, offline_requests_gateway_received,
offline_requests_completed, offline_requests_expired, offline_requests_failed,
duplicate_packets_dropped, invalid_packets_dropped, average_hops, average_retrieval_time_ms`

No payloads, ever.

---

## 10. Battery / data safeguards (§24)

Scan ≤ 90s per request then stop; discovery stops immediately on success, timeout, or app background;
connection idle timeout 30s; packet ≤ 128 KB; forward ≤ 3 peers/packet; exponential backoff 5/15/30s;
relay service auto-stops when the queue is empty; gateway upload on a metered connection requires
`allowMeteredGatewayUpload` (default **false**) — a relay will not spend someone else's mobile data by default.

---

## 11. Phased delivery

| Phase | Work | Exit criterion |
|---|---|---|
| **1** ✅ | Codebase inspection | §0 of this document |
| **2** | `MeshConfig`, `DeviceIdentity`, secure storage, `POST /register-device`, `MeshDevice` model | A hospital login enrols a device; keys survive restart; nothing else changes |
| **3** | `OfflinePacket` + `PacketCodec` + golden vectors (Dart **and** Node) | Byte-identical canonical JSON on both sides |
| **4** | `CryptoManager` + `meshCrypto.js` | Cross-language seal/open round trip in tests |
| **5** | `MeshDatabase`, `RelayCache`, `MeshQueue`, `RouteManager` | Unit tests green, survives restart |
| **6** | `MeshTransport` + `LoopbackTransport` | Integration harness runs 2 virtual nodes |
| **7** | `NearbyTransport` + permissions | Two physical Androids discover each other |
| **8** | `PeerManager` handshake + selection | L1 session established, signed, replay-resistant |
| **9** | `OfflineRequestManager` | Signed sealed packet enqueued and discoverable |
| **10** | `RelayManager` | Scenarios 5, 6, 7, 8 pass |
| **11** | `routes/offlineMesh.js` + `OfflineMeshRequest` + `meshValidation.js` | Endpoints pass backend tests with mock payload |
| **12** | Real data path (`Citizen` + `formatCitizen` reuse) + authorization | `GET /api/citizens/:id` and mesh return identical profiles |
| **13** | Sealed + signed response | Origin decrypts fixture profile |
| **14** | Reverse-path delivery + ack | Scenario 12 passes |
| **15** | `MedicalDataGateway` + `hospital_dashboard` wiring | Online path provably unchanged (scenario 1) |
| **16** | `OfflineMeshProvider` + progress sheet + consent tile | All §29 states render, translated |
| **17** | Full test suite incl. security test | §8 green in CI |
| **18** | Feature flag end-to-end (`/config` remote kill switch) | `OFFLINE_MESH_ENABLED=false` ⇒ behaviour identical to today |
| **19** | 3 physical devices (A offline / B offline / C online) | §12 acceptance checklist signed off |

---

## 12. Deliverables checklist (§40) — to be filled in at completion

1. **Files created** — 26 Dart (§3.1), 5 JS (§4.1), 1 seed script, ~14 test files
2. **Files modified** — 8 Dart, 1 JS, `AndroidManifest.xml`, `pubspec.yaml`, `backend/package.json`
3. **Migrations** — none (Mongoose lazy); `seed/mesh_indexes.js` run once per env
4. **New endpoints** — 7 (§4.5)
5. **Env vars** — 10 (§4.7)
6. **Android permissions** — 9 added (§7)
7. **iOS permissions** — deferred with the iOS transport
8. **Dependencies** — 8 Dart, 0 Node
9. **Architecture diagram** — §1
10. **Sequence diagram** — §4.6 + §3.10
11. **Security assumptions** — §13
12. **Known limitations** — §14
13. **Test results** — §8, after PHASE 17
14. **Manual test instructions** — §15

---

## 13. Security assumptions

- The backend's Ed25519/X25519 private keys and `MESH_SERVER_SECRET` stay secret; a leak breaks E2E confidentiality
  and destination-token opacity.
- `flutter_secure_storage` on a **non-rooted** device protects the private keys. On a rooted/jailbroken device the
  keys are extractable — the mesh then only lets that attacker impersonate *their own* enrolled device, which the
  backend authorizes exactly as it already authorizes that hospital's online JWT. No cross-device escalation.
- Relays are assumed **untrusted and possibly hostile**. They can drop, delay, duplicate, or reorder packets
  (availability attack). They cannot read or forge — forging requires the origin's Ed25519 private key.
- Traffic analysis is **not** mitigated: a relay learns that some enrolled device asked for something at some time,
  and packet sizes are roughly constant but not padded. Padding to a fixed size is a v1.1 item.
- Denial of service on the mesh is possible (a hostile device flooding packets); bounded by TTL, dedupe, size caps,
  forward caps, and backend rate limits, not eliminated.
- The backend still trusts the *existing* authorization model of `GET /api/citizens/:id`, which is currently a
  **public** read. The mesh path is therefore no weaker than today's online path — but it is also no stronger.
  Tightening that read is a separate decision, flagged here because the mesh makes it more visible.

## 14. Known platform limitations

- **iOS has no mesh transport in v1.** Nearby Connections is Android-only; the iOS equivalent (MultipeerConnectivity)
  needs a platform channel and has no maintained Flutter plugin. `MeshTransport.isAvailable()` returns false on iOS
  and the gateway degrades to today's behaviour. The abstraction exists precisely so this is an additive change later.
- **Background relaying is unreliable.** Android throttles BLE/Nearby when the app is backgrounded and Doze applies.
  v1 relays only while the app is in the foreground; a foreground service is a v1.1 consideration with its own
  Play Store disclosure burden.
- **Nearby Connections requires location services enabled** on API < 31 and Bluetooth on regardless — both surfaced
  as explicit user prompts, both counted as `TRANSPORT_DISABLED` when refused.
- **Vercel serverless** means no push to the gateway; the reverse path is driven entirely by the inline HTTP
  response plus the poll fallback.
- **Clock skew** on devices without network time can push `iat` outside the 5-minute window; those devices simply
  cannot use the mesh until their clock is corrected. Detected and surfaced as a distinct error code.
- Emulators cannot exercise Nearby — use `SimulatedTransport` for dev, physical devices for PHASE 19.

## 15. Manual testing instructions (PHASE 19)

**Setup:** 3 Android devices, all with the app installed, all logged in **once while online** (this enrols the
device keys). Backend deployed with `OFFLINE_MESH_ENABLED=true` and the three mesh keys set.

1. Device **C** (gateway): keep mobile data ON. Devices **A** (hospital login) and **B** (relay): Airplane mode ON,
   then Bluetooth ON (and location ON if below Android 12).
2. On **B** and **C**, enable *"Allow SwasthyaTap to use nearby devices…"* in settings.
3. On **A**, open Hospital Dashboard → search a known SwasthyaTap ID (e.g. `x7k9m2`).
4. Expect: "You're offline" → "Searching nearby SwasthyaTap devices…" → "Secure relay found" →
   "Request sent through a nearby device" → "Retrieving medical information…" → profile renders.
5. **Negative:** turn **C**'s data off and repeat → after 120s "Unable to retrieve information offline."
6. **Restart test:** kill **B** mid-relay, reopen it → forwarding resumes, **A** still receives exactly one response.
7. **Isolation test:** on **B**, `adb logcat | grep -i swasthya` during a relay → confirm no name, blood group,
   or profile id appears; only `requestId`/`ttl`/`status`.
8. **Kill switch:** set `OFFLINE_MESH_ENABLED=false` on the backend, relaunch **A** → offline search behaves exactly
   as it does today.

---

## 16. Acceptance criteria (§42)

- [ ] Online retrieval works exactly as before (scenario 1 asserts `ApiService.getCitizen` is still the online path)
- [ ] Offline device generates a signed, sealed request
- [ ] Nearby devices discover and accept it after handshake
- [ ] Duplicate requests rejected (relay cache + backend unique index)
- [ ] TTL prevents endless forwarding
- [ ] Expiration prevents stale requests
- [ ] Gateway submits to `POST /api/offline-mesh/request`
- [ ] Backend authenticates the **original requester** (Ed25519 over registered key), not the gateway
- [ ] Backend returns a sealed, signed response
- [ ] Response travels the reverse route
- [ ] Origin decrypts and renders through the existing `parseCitizen` → `MedicalProfile` → existing UI
- [ ] Relay devices provably cannot decrypt (integration scenario 9)
- [ ] No plaintext medical data in any log (`no_plaintext_logs_test.dart` + manual logcat step 7)
- [ ] Requests survive app restart (scenario 11)
- [ ] Works across 3 physical devices (§15)
- [ ] Disabled by `OFFLINE_MESH_ENABLED=false` with zero behavioural change
