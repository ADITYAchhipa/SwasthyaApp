import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:swasthya_tap/models/models.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/services/auth_storage.dart';
import 'package:swasthya_tap/services/offline_mesh/crypto_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/device_identity.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_logger.dart';
import 'package:swasthya_tap/services/offline_mesh/network_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_request_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/peer_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/relay_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_database.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_queue.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/mesh_transport.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/nearby_transport.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/loopback_transport.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/simulated_transport.dart';

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

  final List<MeshTransport> _transports = [];
  Timer? _sweepTimer;
  Timer? _queueTimer;

  List<MeshTransport> get transports => _transports;

  /// Bootstrap the offline mesh manager.
  Future<void> bootstrap() async {
    // 1. Initialize sqlite db
    await MeshDatabase.instance.database;

    // 2. Load configurations
    await MeshConfig.loadFromPrefs();

    // 3. Load or generate Device identity
    await DeviceIdentity.loadOrCreate();

    // 4. Register available transports
    _transports.clear();
    _transports.add(NearbyTransport());
    _transports.add(LoopbackTransport(nodeId: DeviceIdentity.instance.deviceId));
    _transports.add(SimulatedTransport());

    // 5. Connect transport streams
    for (final transport in _transports) {
      if (await transport.isAvailable()) {
        transport.onPeerDiscovered.listen((peer) {
          PeerManager.instance.addPeer(peer, transport);
        });
        transport.onPeerLost.listen((peer) {
          PeerManager.instance.removePeer(peer.peerId);
        });
        transport.onFrameReceived.listen((frame) {
          RelayManager.instance.handleFrame(frame);
        });
      }
    }

    // 6. Setup background timers
    _sweepTimer?.cancel();
    _sweepTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (MeshConfig.enabled) {
        MeshDatabase.instance.sweepExpired();
      }
    });

    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (MeshConfig.enabled) {
        RelayManager.instance.triggerQueueProcessing();
      }
    });
  }

  /// Evaluates mesh usability (checks consent, flag, identity, and transport status).
  Future<bool> isUsable() async {
    if (!MeshConfig.kEnabledAtBuild || !MeshConfig.enabled) {
      return false;
    }
    if (!DeviceIdentity.hasInstance || !DeviceIdentity.instance.isEnrolled) {
      return false;
    }

    for (final transport in _transports) {
      if (await transport.isAvailable()) {
        return true;
      }
    }
    return false;
  }

  /// Enrolls the device with the server when online.
  Future<void> registerDeviceIfNeeded() async {
    if (!DeviceIdentity.hasInstance) {
      await DeviceIdentity.loadOrCreate();
    }
    final identity = DeviceIdentity.instance;
    if (identity.isEnrolled) {
      return;
    }

    try {
      final myEdPubKey = (await identity.signingKeyPair.extractPublicKey()).bytes;
      final myXPubKey = (await identity.agreementKeyPair.extractPublicKey()).bytes;

      final body = {
        'deviceId': identity.deviceId,
        'signingPublicKey': base64Encode(myEdPubKey),
        'agreementPublicKey': base64Encode(myXPubKey),
      };

      final response = await ApiService.registerMeshDevice(body);
      if (response != null && response['success'] == true) {
        final destToken = response['destinationToken'] as String;
        final serverSignPub = base64Decode(response['serverSigningPublicKey'] as String);
        final serverAgreePub = base64Decode(response['serverAgreementPublicKey'] as String);

        await identity.updateEnrollment(
          destToken: destToken,
          serverSignPub: serverSignPub,
          serverAgreePub: serverAgreePub,
        );

        if (response.containsKey('config')) {
          await MeshConfig.updateRemoteConfig(response['config'] as Map<String, dynamic>);
        }
      }
    } catch (_) {}
  }

  /// Request a patient profile from the offline mesh network.
  Future<MedicalFetchResult> requestMedicalData(
    String idOrToken, {
    void Function(MeshUiState)? onProgress,
  }) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = nowSec + MeshConfig.requestTimeout.inSeconds;
    final rid = const Uuid().v4();
    final myIdentity = DeviceIdentity.instance;

    onProgress?.call(MeshUiState.searching);

    // Start advertising/discovery on all available transports
    for (final transport in _transports) {
      if (await transport.isAvailable()) {
        await transport.startDiscovery(maxDuration: MeshConfig.maxScanDuration);
      }
    }

    // Build the cleartext request payload
    final session = await AuthStorage.loadSession();
    final reqMap = <String, dynamic>{};
    if (session != null) {
      if (session.isHospital) {
        reqMap['role'] = 'hospital';
        reqMap['hospitalId'] = session.hospitalId ?? '';
        reqMap['personnelId'] = '';
      } else {
        reqMap['role'] = 'citizen';
        reqMap['citizenId'] = session.citizenId ?? '';
      }
    }

    final randomBytes = List<int>.generate(24, (i) => (nowSec + i) % 256);
    final b64Nonce = base64Url.encode(randomBytes).replaceAll('=', '');

    final clearPayload = {
      'op': 'FETCH_CITIZEN',
      'ref': idOrToken,
      'req': reqMap,
      'nonce': b64Nonce,
      'iat': nowSec,
    };
    final cleartextBytes = utf8.encode(jsonEncode(clearPayload));

    // Construct the packet header fields to calculate AAD
    final dummyPacket = OfflinePacket(
      v: 1,
      t: 'MEDICAL_DATA_REQUEST',
      rid: rid,
      org: myIdentity.deviceId,
      dst: myIdentity.destinationToken ?? '',
      iat: nowSec,
      exp: exp,
      ttl: MeshConfig.maxTtl,
    );

    // E2E Seal the payload to the server's agreement key
    final serverAgreePub = myIdentity.serverAgreementPublicKey;
    if (serverAgreePub == null) {
      return MedicalFetchResult.failure(MeshFailure.unauthorized);
    }

    final sealed = await CryptoManager.sealL2(
      cleartext: cleartextBytes,
      recipientX25519PubKeyBytes: serverAgreePub,
      aad: dummyPacket.getAadBytes(),
      info: 'swasthyatap/mesh/v1/req',
    );

    // Build the full packet object
    final requestPacket = OfflinePacket(
      v: 1,
      t: 'MEDICAL_DATA_REQUEST',
      rid: rid,
      org: myIdentity.deviceId,
      dst: myIdentity.destinationToken ?? '',
      iat: nowSec,
      exp: exp,
      ttl: MeshConfig.maxTtl,
      epk: sealed['epk']!,
      pay: sealed['pay']!,
    );

    // Compute signature over canonical header representation
    final sig = await CryptoManager.sign(
      message: requestPacket.getCanonicalBytes(),
      keyPair: myIdentity.signingKeyPair,
    );
    requestPacket.sig = base64Url.encode(sig).replaceAll('=', '');

    // Queue for sending
    await MeshQueue.instance.enqueue(requestPacket);

    // Register active completer
    final completer = Completer<OfflinePacket>();
    OfflineRequestManager.instance.registerRequest(rid, completer);

    // Set up UI states based on active peer updates
    final timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final activeSessions = PeerManager.instance.discoveredPeers.values.where((p) {
        return p.state == 'CONNECTED' && PeerManager.instance.hasSession(p.peerId);
      }).toList();

      if (activeSessions.isNotEmpty) {
        onProgress?.call(MeshUiState.relayFound);
      }
    });

    try {
      final responsePacket = await completer.future.timeout(MeshConfig.requestTimeout);
      timer.cancel();

      // Clean up transport discovery
      for (final transport in _transports) {
        await transport.stopDiscovery();
      }

      onProgress?.call(MeshUiState.received);

      // Decrypt L2 Response Payload
      final decryptedBytes = await CryptoManager.openL2(
        sealedBytes: base64Url.decode(responsePacket.pay),
        ephemeralPubKeyBytes: base64Url.decode(responsePacket.epk),
        recipientKeyPair: myIdentity.agreementKeyPair,
        aad: responsePacket.getAadBytes(),
        info: 'swasthyatap/mesh/v1/resp',
      );

      final decryptedStr = utf8.decode(decryptedBytes);
      final decryptedJson = jsonDecode(decryptedStr) as Map<String, dynamic>;
      final citizenData = decryptedJson['citizen'] as Map<String, dynamic>;

      final profile = ApiService.parseCitizen(citizenData);
      return MedicalFetchResult.mesh(profile);
    } on TimeoutException {
      timer.cancel();
      OfflineRequestManager.instance.removeRequest(rid);
      for (final transport in _transports) {
        await transport.stopDiscovery();
      }
      onProgress?.call(MeshUiState.failed);
      return MedicalFetchResult.failure(MeshFailure.timeout);
    } catch (_) {
      timer.cancel();
      OfflineRequestManager.instance.removeRequest(rid);
      for (final transport in _transports) {
        await transport.stopDiscovery();
      }
      onProgress?.call(MeshUiState.failed);
      return MedicalFetchResult.failure(MeshFailure.unknown);
    }
  }

  /// Clean up and dispose.
  Future<void> dispose() async {
    _sweepTimer?.cancel();
    _queueTimer?.cancel();
    for (final transport in _transports) {
      await transport.dispose();
    }
  }
}
