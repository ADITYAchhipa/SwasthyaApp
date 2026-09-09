import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:swasthya_tap/services/api_service.dart';
import 'package:swasthya_tap/services/offline_mesh/crypto_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_logger.dart';
import 'package:swasthya_tap/services/offline_mesh/network_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_request_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_response_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/peer_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/store/relay_cache.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_queue.dart';
import 'package:swasthya_tap/services/offline_mesh/store/route_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/mesh_transport.dart';

class RelayManager {
  static final RelayManager instance = RelayManager._internal();
  RelayManager._internal();

  /// Processes an incoming raw frame from a peer.
  Future<void> handleFrame(MeshFrame frame) async {
    final peerId = frame.peerId;
    final sessionKey = PeerManager.instance.getSessionKey(peerId);

    // 1. Handshake path (cleartext)
    if (sessionKey == null) {
      try {
        final rawStr = utf8.decode(frame.data);
        final json = jsonDecode(rawStr) as Map<String, dynamic>;
        final packet = OfflinePacket.fromJson(json);
        if (packet.t == 'HANDSHAKE_INIT' || packet.t == 'HANDSHAKE_ACK') {
          await PeerManager.instance.handleHandshakeFrame(frame, packet);
        }
      } catch (_) {}
      return;
    }

    // 2. Data path (L1-encrypted)
    try {
      final decrypted = await CryptoManager.decryptL1(
        sealedBytes: frame.data,
        sessionKey: sessionKey,
      );

      final rawStr = utf8.decode(decrypted);
      final json = jsonDecode(rawStr) as Map<String, dynamic>;
      final packet = OfflinePacket.fromJson(json);

      await processPacket(packet, senderPeerId: peerId);
    } catch (e) {
      MeshLogger.logError('DECRYPTION_FAILED', transportId: 'nearby');
    }
  }

  /// Evaluates and routes an OfflinePacket.
  Future<void> processPacket(OfflinePacket packet, {required String senderPeerId}) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // A. Packet verification
    if (packet.v != 1) {
      MeshLogger.logError('UNKNOWN_VERSION', requestId: packet.rid);
      return;
    }

    if (packet.exp <= nowSec || (packet.iat - nowSec).abs() > 300) {
      MeshLogger.logError('REQUEST_EXPIRED', requestId: packet.rid);
      return;
    }

    if (packet.ttl <= 0) {
      MeshLogger.logError('TTL_EXCEEDED', requestId: packet.rid);
      return;
    }

    // B. Deduplication check
    final isDuplicate = await RelayCache.instance.contains(packet.rid);
    
    // We only process duplicates if we are the originator waiting for a RESPONSE
    if (isDuplicate) {
      if (packet.t == 'MEDICAL_DATA_RESPONSE' && OfflineRequestManager.instance.isPending(packet.rid)) {
        // Let it fall through so we can resolve the completer
      } else {
        MeshLogger.log({
          'requestId': packet.rid,
          'packetType': packet.t,
          'status': 'duplicate_dropped',
        });
        return;
      }
    }

    // C. Add to seen request cache
    await RelayCache.instance.addSeenRequest(
      requestId: packet.rid,
      packetType: packet.t,
      expiresAt: packet.exp,
    );

    // D. Process based on packet type
    if (packet.t == 'MEDICAL_DATA_REQUEST') {
      // Save routing entry for the reverse path
      await RouteManager.instance.addRoute(
        requestId: packet.rid,
        previousPeer: senderPeerId,
        nextPeer: '',
        hops: packet.ttl,
        expiresAt: packet.exp,
      );

      // Decrement hop limit
      packet.ttl--;

      // Check if this device can act as a Gateway
      final hasInternet = await NetworkManager.instance.isInternetAvailable();
      if (hasInternet) {
        try {
          MeshLogger.log({
            'requestId': packet.rid,
            'packetType': packet.t,
            'status': 'gateway_received',
          });

          // Upload request to backend
          final responseData = await ApiService.submitMeshPacket(packet.toJson());
          if (responseData != null && responseData['success'] == true) {
            final responsePacketJson = responseData['response'] as Map<String, dynamic>;
            final responsePacket = OfflinePacket.fromJson(responsePacketJson);

            // Mark request complete in our cache
            await RelayCache.instance.markCompleted(packet.rid);

            // Route RESPONSE back along the reverse path
            await processPacket(responsePacket, senderPeerId: '');
          } else {
            // Failed to submit to gateway, queue for peer forwarding
            await _enqueueAndForward(packet);
          }
        } catch (e) {
          await _enqueueAndForward(packet);
        }
      } else {
        // Relay only: queue and forward
        await _enqueueAndForward(packet);
      }
    } else if (packet.t == 'MEDICAL_DATA_RESPONSE') {
      // Check if we are the requesting originator
      if (OfflineRequestManager.instance.isPending(packet.rid)) {
        await OfflineResponseManager.instance.handleResponse(packet);
        await RelayCache.instance.markCompleted(packet.rid);
        await RouteManager.instance.deleteRoute(packet.rid);
        return;
      }

      // Relay: look up the reverse route path
      final route = await RouteManager.instance.getRoute(packet.rid);
      if (route != null && route.previousPeer.isNotEmpty) {
        final success = await _sendToPeer(route.previousPeer, packet);
        if (success) {
          await RelayCache.instance.markCompleted(packet.rid);
          await RouteManager.instance.deleteRoute(packet.rid);
        }
      }
    }
  }

  Future<void> _enqueueAndForward(OfflinePacket packet) async {
    await MeshQueue.instance.enqueue(packet);
    await triggerQueueProcessing();
  }

  /// Processes outbound items currently in the queue, attempting to forward them to eligible peers.
  Future<void> triggerQueueProcessing() async {
    final pending = await MeshQueue.instance.getPendingPackets();
    if (pending.isEmpty) return;

    for (final item in pending) {
      final selectedPeers = PeerManager.instance.selectPeersForPacket(item);
      if (selectedPeers.isEmpty) continue;

      await MeshQueue.instance.updateState(item.id, 'FORWARDING');

      bool sentToAny = false;
      for (final peer in selectedPeers) {
        final success = await _sendToPeer(peer.peerId, item.packet);
        if (success) {
          sentToAny = true;
          await MeshQueue.instance.recordAttempt(item, sentToPeer: peer.peerId);
        }
      }

      if (sentToAny) {
        await MeshQueue.instance.updateState(item.id, 'FORWARDED');
      } else {
        await MeshQueue.instance.updateState(item.id, 'FAILED');
      }
    }
  }

  Future<bool> _sendToPeer(String peerId, OfflinePacket packet) async {
    final transport = PeerManager.instance.getTransport(peerId);
    final sessionKey = PeerManager.instance.getSessionKey(peerId);

    if (transport == null || sessionKey == null) return false;

    try {
      final clearBytes = utf8.encode(jsonEncode(packet.toJson()));
      final sealedBytes = await CryptoManager.encryptL1(
        cleartext: clearBytes,
        sessionKey: sessionKey,
      );

      return await transport.sendFrame(peerId, Uint8List.fromList(sealedBytes));
    } catch (_) {
      return false;
    }
  }
}
