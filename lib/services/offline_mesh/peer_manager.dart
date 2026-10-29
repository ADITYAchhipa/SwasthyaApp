import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:swasthya_tap/services/offline_mesh/crypto_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/device_identity.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_queue.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/mesh_transport.dart';

class PeerManager {
  static final PeerManager instance = PeerManager._internal();
  PeerManager._internal();

  final Map<String, MeshPeer> _discoveredPeers = {};
  final Map<String, SecretKey> _sessionKeys = {};
  final Map<String, List<int>> _peerHandshakeNonces = {};
  final Map<String, MeshTransport> _peerTransports = {};

  final _handshakeCompleteController = StreamController<String>.broadcast();
  Stream<String> get onHandshakeComplete => _handshakeCompleteController.stream;

  Map<String, MeshPeer> get discoveredPeers => _discoveredPeers;

  /// Register/update peer discovered via transport
  void addPeer(MeshPeer peer, MeshTransport transport) {
    _discoveredPeers[peer.peerId] = peer;
    _peerTransports[peer.peerId] = transport;

    if (peer.state == 'CONNECTED' && !_sessionKeys.containsKey(peer.peerId)) {
      // Auto-trigger handshake as initiator when connected
      _sendHandshakeInit(peer.peerId, transport);
    } else if (peer.state == 'DISCONNECTED' || peer.state == 'DISCOVERED') {
      transport.connectToPeer(peer.peerId);
    }
  }

  /// Remove peer
  void removePeer(String peerId) {
    _discoveredPeers.remove(peerId);
    _sessionKeys.remove(peerId);
    _peerHandshakeNonces.remove(peerId);
    _peerTransports.remove(peerId);
  }

  /// Check if session is established with peer
  bool hasSession(String peerId) => _sessionKeys.containsKey(peerId);

  /// Get L1 session key
  SecretKey? getSessionKey(String peerId) => _sessionKeys[peerId];

  /// Get transport for peer
  MeshTransport? getTransport(String peerId) => _peerTransports[peerId];

  /// Send L1 Handshake Init
  Future<void> _sendHandshakeInit(String peerId, MeshTransport transport) async {
    try {
      final myIdentity = DeviceIdentity.instance;
      final nonceA = List<int>.generate(12, (i) => i + 1); // simple random nonce or generated
      final randomBox = AesGcm.with256bits().newNonce(); // real random bytes
      final nonce = randomBox;
      _peerHandshakeNonces[peerId] = nonce;

      final myEdPubKey = (await myIdentity.signingKeyPair.extractPublicKey()).bytes;
      final myXPubKey = (await myIdentity.agreementKeyPair.extractPublicKey()).bytes;

      final payloadObj = {
        'nonce': base64Url.encode(nonce).replaceAll('=', ''),
        'ed25519_pub': base64Url.encode(myEdPubKey).replaceAll('=', ''),
      };

      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final packet = OfflinePacket(
        v: 1,
        t: 'HANDSHAKE_INIT',
        rid: const Uuid().v4(),
        org: myIdentity.deviceId,
        iat: iat,
        exp: iat + 300,
        ttl: 1,
        epk: base64Url.encode(myXPubKey).replaceAll('=', ''),
        pay: base64Url.encode(utf8.encode(jsonEncode(payloadObj))).replaceAll('=', ''),
      );

      // Sign the handshake packet
      final sig = await CryptoManager.sign(
        message: packet.getCanonicalBytes(),
        keyPair: myIdentity.signingKeyPair,
      );
      packet.sig = base64Url.encode(sig).replaceAll('=', '');

      final frameData = utf8.encode(jsonEncode(packet.toJson()));
      await transport.sendFrame(peerId, Uint8List.fromList(frameData));
    } catch (_) {}
  }

  /// Handle handshake message
  Future<void> handleHandshakeFrame(MeshFrame frame, OfflinePacket packet) async {
    final peerId = frame.peerId;
    final transport = _peerTransports[peerId];
    if (transport == null) return;

    try {
      final myIdentity = DeviceIdentity.instance;
      final iat = packet.iat;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Validate time window (5 mins)
      if ((nowSec - iat).abs() > 300) return;

      final payStr = utf8.decode(base64Url.decode(packet.pay));
      final Map<String, dynamic> payMap = jsonDecode(payStr);

      final peerNonce = base64Url.decode(payMap['nonce'] as String);
      final peerEdPubKey = base64Url.decode(payMap['ed25519_pub'] as String);
      final peerXPubKey = base64Url.decode(packet.epk);

      // Verify signature
      final isSigValid = await CryptoManager.verify(
        message: packet.getCanonicalBytes(),
        signatureBytes: base64Url.decode(packet.sig),
        ed25519PubKeyBytes: peerEdPubKey,
      );

      if (!isSigValid) return;

      if (packet.t == 'HANDSHAKE_INIT') {
        // We received HANDSHAKE_INIT, so generate local nonceB, compute session key, and send HANDSHAKE_ACK
        final nonceB = AesGcm.with256bits().newNonce();
        final myEdPubKey = (await myIdentity.signingKeyPair.extractPublicKey()).bytes;
        final myXPubKey = (await myIdentity.agreementKeyPair.extractPublicKey()).bytes;

        final sessionKey = await CryptoManager.deriveL1SessionKey(
          myKeyPair: myIdentity.agreementKeyPair,
          peerX25519PubKeyBytes: peerXPubKey,
          nonceA: peerNonce,
          nonceB: nonceB,
        );

        _sessionKeys[peerId] = sessionKey;

        // Send HANDSHAKE_ACK
        final ackPayloadObj = {
          'nonce': base64Url.encode(nonceB).replaceAll('=', ''),
          'ed25519_pub': base64Url.encode(myEdPubKey).replaceAll('=', ''),
        };

        final responseIat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final ackPacket = OfflinePacket(
          v: 1,
          t: 'HANDSHAKE_ACK',
          rid: packet.rid,
          org: myIdentity.deviceId,
          iat: responseIat,
          exp: responseIat + 300,
          ttl: 1,
          epk: base64Url.encode(myXPubKey).replaceAll('=', ''),
          pay: base64Url.encode(utf8.encode(jsonEncode(ackPayloadObj))).replaceAll('=', ''),
        );

        final sig = await CryptoManager.sign(
          message: ackPacket.getCanonicalBytes(),
          keyPair: myIdentity.signingKeyPair,
        );
        ackPacket.sig = base64Url.encode(sig).replaceAll('=', '');

        final frameData = utf8.encode(jsonEncode(ackPacket.toJson()));
        await transport.sendFrame(peerId, Uint8List.fromList(frameData));
        _handshakeCompleteController.add(peerId);

      } else if (packet.t == 'HANDSHAKE_ACK') {
        // We received HANDSHAKE_ACK, so compute session key using stored nonceA
        final nonceA = _peerHandshakeNonces[peerId];
        if (nonceA == null) return; // invalid handshake sequence

        final sessionKey = await CryptoManager.deriveL1SessionKey(
          myKeyPair: myIdentity.agreementKeyPair,
          peerX25519PubKeyBytes: peerXPubKey,
          nonceA: nonceA,
          nonceB: peerNonce,
        );

        _sessionKeys[peerId] = sessionKey;
        _handshakeCompleteController.add(peerId);
      }
    } catch (_) {}
  }

  /// Select the best peers to forward a packet to based on plan selection rules
  List<MeshPeer> selectPeersForPacket(QueueItem item) {
    // 1. Get all connected peers with active sessions
    final candidates = _discoveredPeers.values.where((peer) {
      return peer.state == 'CONNECTED' && _sessionKeys.containsKey(peer.peerId);
    }).toList();

    // 2. Filter out peers who have already received this packet
    final filtered = candidates.where((peer) {
      return !item.forwardedPeers.contains(peer.peerId);
    }).toList();

    // 3. Sort based on selection score (descending):
    //    - Advertised gateway first
    //    - Lowest hop hint
    //    - Highest RSSI (or arbitrary stable sorting)
    filtered.sort((a, b) {
      if (a.advertisedHasInternet != b.advertisedHasInternet) {
        return a.advertisedHasInternet ? -1 : 1;
      }
      if (a.hopHint != b.hopHint) {
        return a.hopHint.compareTo(b.hopHint);
      }
      if (a.rssi != null && b.rssi != null) {
        return b.rssi!.compareTo(a.rssi!); // higher rssi first
      }
      return a.peerId.compareTo(b.peerId); // deterministic fallback
    });

    // 4. Return top up to MeshConfig.maxForwardAttemptsPerPacket (default 3)
    final limit = MeshConfig.maxForwardAttemptsPerPacket;
    return filtered.length > limit ? filtered.sublist(0, limit) : filtered;
  }

  void dispose() {
    _handshakeCompleteController.close();
  }

  void clearSessions() {
    _discoveredPeers.clear();
    _sessionKeys.clear();
    _peerHandshakeNonces.clear();
    _peerTransports.clear();
  }
}
