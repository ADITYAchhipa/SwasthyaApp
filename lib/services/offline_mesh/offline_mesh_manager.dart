import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:swasthya_tap/models/models.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/services/auth_storage.dart';
import 'crypto_manager.dart';
import 'device_identity.dart';
import 'mesh_config.dart';
import 'mesh_read_policy.dart';
import 'offline_packet.dart';
import 'offline_request_manager.dart';
import 'peer_manager.dart';
import 'relay_manager.dart';
import 'store/mesh_database.dart';
import 'store/mesh_queue.dart';
import 'transport/mesh_transport.dart';
import 'transport/nearby_transport.dart';

enum MeshUiState {
  offline,
  searching,
  relayFound,
  sent,
  awaiting,
  received,
  failed,
}

enum MeshFailure {
  timeout,
  unauthorized,
  transportDisabled,
  noPeers,
  unknown,
}

enum MedicalFetchSource { online, mesh, localCache }

class MedicalFetchResult {
  final MedicalProfile? profile;
  final MedicalFetchSource? source;
  final MeshFailure? failure;

  MedicalFetchResult({
    this.profile,
    this.source,
    this.failure,
  });

  factory MedicalFetchResult.online(MedicalProfile profile) =>
      MedicalFetchResult(profile: profile, source: MedicalFetchSource.online);

  factory MedicalFetchResult.mesh(MedicalProfile profile) =>
      MedicalFetchResult(profile: profile, source: MedicalFetchSource.mesh);

  factory MedicalFetchResult.localCache(MedicalProfile? profile) =>
      MedicalFetchResult(profile: profile, source: MedicalFetchSource.localCache);

  factory MedicalFetchResult.failure(MeshFailure failure) =>
      MedicalFetchResult(failure: failure);
}

class OfflineMeshManager {
  static final OfflineMeshManager instance = OfflineMeshManager._internal();
  OfflineMeshManager._internal();
  static const MethodChannel _backgroundChannel = MethodChannel('in.swasthyatap.mesh/background_service');
  final List<MeshTransport> _transports = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _sweepTimer;
  Timer? _queueTimer;
  int _generation = 0;
  bool _initialized = false;
  Future<void>? _bootstrap;
  List<MeshTransport> get transports => _transports;

  Future<void> syncBackgroundService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (MeshConfig.enabled && MeshConfig.backgroundRelay) {
        await _backgroundChannel.invokeMethod('startBackgroundRelay');
      } else {
        await _backgroundChannel.invokeMethod('stopBackgroundRelay');
      }
    } catch (_) {}
  }

  Future<void> bootstrap() => _bootstrap ??= _start().whenComplete(() => _bootstrap = null);

  Future<void> _start() async {
    if (!MeshConfig.kEnabledAtBuild || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final generation = _generation;
    try {
      await MeshConfig.loadFromPrefs();
      final config = await ApiService.getMeshConfig();
      if (config != null) await MeshConfig.updateRemoteConfig(config);
      if (!MeshConfig.enabled || generation != _generation) return;
      await DeviceIdentity.loadOrCreate();
      await registerDeviceIfNeeded();
      if (!MeshConfig.enabled || generation != _generation) return;
      OfflineRequestManager.instance.clearAll();
      await MeshDatabase.instance.sweepExpired();
      if (!_initialized) {
        _initialized = true;
        _transports.add(NearbyTransport());
        for (final transport in _transports) {
          _subscriptions.add(transport.onPeerDiscovered.listen((peer) {
            if (MeshConfig.enabled) PeerManager.instance.addPeer(peer, transport);
          }));
          _subscriptions.add(transport.onPeerLost.listen((peer) => PeerManager.instance.removePeer(peer.peerId)));
          _subscriptions.add(transport.onFrameReceived.listen((frame) {
            if (MeshConfig.enabled) RelayManager.instance.handleFrame(frame);
          }));
        }
        _sweepTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          MeshDatabase.instance.sweepExpired();
        });
        _queueTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          if (MeshConfig.enabled) {
            await RelayManager.instance.triggerQueueProcessing();
            if (MeshConfig.backgroundRelay) {
              for (final transport in _transports) {
                if (transport is NearbyTransport && !transport.isDiscovering && await transport.isAvailable()) {
                  await transport.startDiscovery(maxDuration: MeshConfig.maxScanDuration);
                }
              }
            }
          }
        });
      }
      // Relay participation requires consent; enrollment alone never starts it.
      for (final transport in _transports) {
        if (await transport.isAvailable()) {
          await transport.startDiscovery(maxDuration: MeshConfig.maxScanDuration);
        }
      }
      await syncBackgroundService();
    } catch (_) {
      MeshConfig.enabled = false; // plugin/config failure must not block online startup
    }
  }

  Future<bool> isUsable() async => MeshConfig.enabled && DeviceIdentity.hasInstance &&
      DeviceIdentity.instance.isEnrolled && _transports.isNotEmpty;

  Future<void> registerDeviceIfNeeded() async {
    if (!MeshConfig.kEnabledAtBuild || !MeshConfig.enabled) return;
    final token = await AuthStorage.getToken();
    if (token == null) return;
    if (!DeviceIdentity.hasInstance) await DeviceIdentity.loadOrCreate();
    final identity = DeviceIdentity.instance;
    final signing = base64Encode((await identity.signingKeyPair.extractPublicKey()).bytes);
    final agreement = base64Encode((await identity.agreementKeyPair.extractPublicKey()).bytes);
    final proof = await CryptoManager.sign(
      message: utf8.encode(jsonEncode([2, 'REGISTER_DEVICE', identity.deviceId, signing, agreement,
        sha256.convert(utf8.encode(token)).toString()])), keyPair: identity.signingKeyPair);
    final response = await ApiService.registerMeshDevice({
      'deviceId': identity.deviceId, 'signingPublicKey': signing, 'agreementPublicKey': agreement,
      'proof': base64Url.encode(proof).replaceAll('=', ''),
    });
    if (!MeshConfig.enabled || !DeviceIdentity.hasInstance || DeviceIdentity.instance != identity) return;
    if (response != null && response['success'] == true) {
      await identity.updateEnrollment(destToken: response['destinationToken'] as String,
        serverSignPub: base64Decode(response['serverSigningPublicKey'] as String),
        serverAgreePub: base64Decode(response['serverAgreementPublicKey'] as String));
      await MeshConfig.updateRemoteConfig(response['config'] as Map<String, dynamic>);
    }
  }

  /// Patient reads initiated by an authorized doctor over the mesh network.
  Future<MedicalFetchResult> requestMedicalData(String idOrToken, {
    void Function(MeshUiState)? onProgress,
  }) async {
    final res = await requestPatient(idOrToken, onProgress: onProgress);
    if (res != null && res['patient'] != null) {
      return MedicalFetchResult(
        profile: ApiService.parseCitizen(res['patient'] as Map<String, dynamic>),
        source: 'mesh',
      );
    }
    return MedicalFetchResult.failure(MeshFailure.unauthorized);
  }

  /// Returns an authenticated, time-bounded snapshot of patient data over mesh.
  /// Origin must be an authorized doctor; enforced and validated by backend.
  Future<Map<String, dynamic>?> requestPatient(String patientRef, {
    void Function(MeshUiState)? onProgress,
  }) async {
    if (!MeshReadPolicy.validPatientId(patientRef) || !await isUsable()) return null;
    final generation = _generation;
    final identity = DeviceIdentity.instance;
    final token = await AuthStorage.getToken();
    if (token == null || generation != _generation) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rid = const Uuid().v4();
    final header = OfflinePacket(v: 2, t: 'MEDICAL_DATA_REQUEST', op: MeshReadPolicy.readPatientOp,
      rid: rid, org: identity.deviceId, dst: identity.destinationToken!,
      iat: now, exp: now + MeshReadPolicy.maxLifetimeSeconds, ttl: MeshReadPolicy.maxHops);
    bool registered = false;
    try {
      final sealed = await CryptoManager.sealL2(
        cleartext: utf8.encode(jsonEncode({'op': MeshReadPolicy.readPatientOp, 'ref': patientRef, 'token': token})),
        recipientX25519PubKeyBytes: identity.serverAgreementPublicKey!, aad: header.getAadBytes(),
        info: 'swasthyatap/mesh/v2/req');
      final packet = OfflinePacket(v: 2, t: header.t, op: header.op, rid: rid, org: header.org,
        dst: header.dst, iat: now, exp: header.exp, ttl: header.ttl, epk: sealed['epk']!, pay: sealed['pay']!);
      packet.sig = base64Url.encode(await CryptoManager.sign(message: packet.getCanonicalBytes(),
        keyPair: identity.signingKeyPair)).replaceAll('=', '');
      if (generation != _generation || !MeshConfig.enabled) return null;
      final completer = Completer<OfflinePacket>();
      OfflineRequestManager.instance.registerRequest(rid, completer);
      registered = true;
      final responseFuture = completer.future.timeout(MeshConfig.requestTimeout);
      final enqueue = () async {
        await MeshQueue.instance.enqueue(packet);
        onProgress?.call(MeshUiState.searching);
        for (final transport in _transports) {
          await transport.startDiscovery(maxDuration: MeshConfig.maxScanDuration);
        }
        await RelayManager.instance.triggerQueueProcessing();
      };
      unawaited(enqueue().catchError((Object _) {
        OfflineRequestManager.instance.failRequest(rid, StateError('MESH_UNAVAILABLE'));
      }));
      final response = await responseFuture;
      if (generation != _generation || !MeshConfig.enabled || !response.isValidReadPacket()) return null;
      final bytes = await CryptoManager.openL2(sealedBytes: base64Url.decode(response.pay),
        ephemeralPubKeyBytes: base64Url.decode(response.epk), recipientKeyPair: identity.agreementKeyPair,
        aad: response.getAadBytes(), info: 'swasthyatap/mesh/v2/resp');
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (generation != _generation || !MeshConfig.enabled || data['ok'] != true ||
          data['exp'] != response.exp || data['rid'] != rid ||
          response.exp <= DateTime.now().millisecondsSinceEpoch ~/ 1000) return null;
      final currentToken = await AuthStorage.getToken();
      if (currentToken == null || currentToken != token) return null;
      data['deliveredAt'] = DateTime.now().toUtc().toIso8601String();
      data['source'] = 'mesh';
      onProgress?.call(MeshUiState.received);
      return data;
    } catch (_) {
      onProgress?.call(MeshUiState.failed);
      return null;
    } finally {
      if (registered) {
        OfflineRequestManager.instance.removeRequest(rid);
        await MeshQueue.instance.remove(rid);
      }
    }
  }

  /// Returns an authenticated, time-bounded snapshot of hospital directory data.
  /// No plaintext persistence and no arbitrary operation/URL/body input.
  Future<Map<String, dynamic>?> requestHospital(String hospitalId, {
    void Function(MeshUiState)? onProgress,
  }) async {
    if (!MeshReadPolicy.validHospitalId(hospitalId) || !await isUsable()) return null;
    final generation = _generation;
    final identity = DeviceIdentity.instance;
    final token = await AuthStorage.getToken();
    if (token == null || generation != _generation) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rid = const Uuid().v4();
    final header = OfflinePacket(v: 2, t: 'MEDICAL_DATA_REQUEST', op: MeshReadPolicy.operation,
      rid: rid, org: identity.deviceId, dst: identity.destinationToken!,
      iat: now, exp: now + MeshReadPolicy.maxLifetimeSeconds, ttl: MeshReadPolicy.maxHops);
    bool registered = false;
    try {
      final sealed = await CryptoManager.sealL2(
        cleartext: utf8.encode(jsonEncode({'op': MeshReadPolicy.operation, 'ref': hospitalId, 'token': token})),
        recipientX25519PubKeyBytes: identity.serverAgreementPublicKey!, aad: header.getAadBytes(),
        info: 'swasthyatap/mesh/v2/req');
      final packet = OfflinePacket(v: 2, t: header.t, op: header.op, rid: rid, org: header.org,
        dst: header.dst, iat: now, exp: header.exp, ttl: header.ttl, epk: sealed['epk']!, pay: sealed['pay']!);
      packet.sig = base64Url.encode(await CryptoManager.sign(message: packet.getCanonicalBytes(),
        keyPair: identity.signingKeyPair)).replaceAll('=', '');
      if (generation != _generation || !MeshConfig.enabled) return null;
      final completer = Completer<OfflinePacket>();
      OfflineRequestManager.instance.registerRequest(rid, completer);
      registered = true;
      // Attach timeout/error handling before asynchronous enqueue/discovery.
      final responseFuture = completer.future.timeout(MeshConfig.requestTimeout);
      final enqueue = () async {
        await MeshQueue.instance.enqueue(packet);
        onProgress?.call(MeshUiState.searching);
        for (final transport in _transports) {
          await transport.startDiscovery(maxDuration: MeshConfig.maxScanDuration);
        }
        await RelayManager.instance.triggerQueueProcessing();
      };
      unawaited(enqueue().catchError((Object _) {
        OfflineRequestManager.instance.failRequest(rid, StateError('MESH_UNAVAILABLE'));
      }));
      final response = await responseFuture;
      if (generation != _generation || !MeshConfig.enabled || !response.isValidReadPacket()) return null;
      final bytes = await CryptoManager.openL2(sealedBytes: base64Url.decode(response.pay),
        ephemeralPubKeyBytes: base64Url.decode(response.epk), recipientKeyPair: identity.agreementKeyPair,
        aad: response.getAadBytes(), info: 'swasthyatap/mesh/v2/resp');
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (generation != _generation || !MeshConfig.enabled || data['ok'] != true ||
          data['exp'] != response.exp || data['rid'] != rid ||
          response.exp <= DateTime.now().millisecondsSinceEpoch ~/ 1000) return null;
      final currentToken = await AuthStorage.getToken();
      if (currentToken == null || currentToken != token) return null;
      data['deliveredAt'] = DateTime.now().toUtc().toIso8601String();
      data['source'] = 'mesh';
      onProgress?.call(MeshUiState.received);
      return data;
    } catch (_) {
      onProgress?.call(MeshUiState.failed);
      return null;
    } finally {
      if (registered) {
        OfflineRequestManager.instance.removeRequest(rid);
        await MeshQueue.instance.remove(rid);
      }
    }
  }

  /// Synchronously invalidates pending deliveries, then clears local ciphertext,
  /// connections and private keys. Offline logout cannot recall already sent data.
  Future<void> stop({String? revokeToken, bool clearIdentity = false}) async {
    _generation++;
    MeshConfig.enabled = false;
    await syncBackgroundService();
    OfflineRequestManager.instance.clearAll();
    final deviceId = DeviceIdentity.hasInstance ? DeviceIdentity.instance.deviceId : null;
    if (revokeToken != null && deviceId != null) {
      unawaited(ApiService.revokeMeshDevice(deviceId, revokeToken));
    }
    _sweepTimer?.cancel();
    _queueTimer?.cancel();
    for (final subscription in _subscriptions) {
      try { await subscription.cancel(); } catch (_) {}
    }
    _subscriptions.clear();
    for (final transport in _transports) {
      try { await transport.dispose(); } catch (_) {}
    }
    _transports.clear();
    try { PeerManager.instance.clearSessions(); } catch (_) {}
    if (_initialized) {
      try { await MeshDatabase.instance.clearAll(); } catch (_) {}
    }
    _initialized = false;
    if (clearIdentity && DeviceIdentity.hasInstance) {
      try { await DeviceIdentity.clearIdentity(); } catch (_) {}
    }
  }

  Future<void> dispose() => stop();
}
