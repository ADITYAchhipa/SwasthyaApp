import 'dart:async';
import 'dart:typed_data';
import 'package:swasthya_tap/services/offline_mesh/transport/mesh_transport.dart';

class LoopbackRegistry {
  static final Map<String, LoopbackTransport> _nodes = {};

  static void register(String nodeId, LoopbackTransport transport) {
    _nodes[nodeId] = transport;
  }

  static void unregister(String nodeId) {
    _nodes.remove(nodeId);
  }

  static Map<String, LoopbackTransport> get nodes => _nodes;
}

class LoopbackTransport extends MeshTransport {
  final String nodeId;
  final bool hasInternet;

  final _peerDiscoveredController = StreamController<MeshPeer>.broadcast();
  final _peerLostController = StreamController<MeshPeer>.broadcast();
  final _frameReceivedController = StreamController<MeshFrame>.broadcast();

  LoopbackTransport({required this.nodeId, this.hasInternet = false}) {
    LoopbackRegistry.register(nodeId, this);
  }

  @override
  String get id => 'loopback';

  @override
  Stream<MeshPeer> get onPeerDiscovered => _peerDiscoveredController.stream;

  @override
  Stream<MeshPeer> get onPeerLost => _peerLostController.stream;

  @override
  Stream<MeshFrame> get onFrameReceived => _frameReceivedController.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> startDiscovery({Duration? maxDuration}) async {
    // Announce self to all other active loopback nodes
    for (final other in LoopbackRegistry.nodes.values) {
      if (other.nodeId == nodeId) continue;

      // Tell other that we are discovered
      other.handleDiscoveredPeer(MeshPeer(
        peerId: nodeId,
        transportId: id,
        lastSeen: DateTime.now(),
        state: 'DISCONNECTED',
        advertisedHasInternet: hasInternet,
        hopHint: hasInternet ? 1 : 2,
      ));

      // Discovered other
      handleDiscoveredPeer(MeshPeer(
        peerId: other.nodeId,
        transportId: id,
        lastSeen: DateTime.now(),
        state: 'DISCONNECTED',
        advertisedHasInternet: other.hasInternet,
        hopHint: other.hasInternet ? 1 : 2,
      ));
    }

    if (maxDuration != null) {
      Future.delayed(maxDuration, stopDiscovery);
    }
  }

  void handleDiscoveredPeer(MeshPeer peer) {
    _peerDiscoveredController.add(peer);
  }

  @override
  Future<void> stopDiscovery() async {
    for (final other in LoopbackRegistry.nodes.values) {
      if (other.nodeId == nodeId) continue;
      
      other._peerLostController.add(MeshPeer(
        peerId: nodeId,
        transportId: id,
        lastSeen: DateTime.now(),
        state: 'DISCONNECTED',
        advertisedHasInternet: hasInternet,
        hopHint: 99,
      ));
    }
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    final other = LoopbackRegistry.nodes[peerId];
    if (other == null) return false;

    // Trigger connected status on both sides
    final now = DateTime.now();
    _peerDiscoveredController.add(MeshPeer(
      peerId: peerId,
      transportId: id,
      lastSeen: now,
      state: 'CONNECTED',
      advertisedHasInternet: other.hasInternet,
      hopHint: other.hasInternet ? 1 : 2,
    ));

    other._peerDiscoveredController.add(MeshPeer(
      peerId: nodeId,
      transportId: id,
      lastSeen: now,
      state: 'CONNECTED',
      advertisedHasInternet: hasInternet,
      hopHint: hasInternet ? 1 : 2,
    ));

    return true;
  }

  @override
  Future<void> disconnectPeer(String peerId) async {
    final other = LoopbackRegistry.nodes[peerId];
    if (other == null) return;

    final now = DateTime.now();
    _peerLostController.add(MeshPeer(
      peerId: peerId,
      transportId: id,
      lastSeen: now,
      state: 'DISCONNECTED',
      advertisedHasInternet: other.hasInternet,
      hopHint: 99,
    ));

    other._peerLostController.add(MeshPeer(
      peerId: nodeId,
      transportId: id,
      lastSeen: now,
      state: 'DISCONNECTED',
      advertisedHasInternet: hasInternet,
      hopHint: 99,
    ));
  }

  @override
  Future<bool> sendFrame(String peerId, Uint8List frame) async {
    final other = LoopbackRegistry.nodes[peerId];
    if (other == null) return false;

    other._frameReceivedController.add(MeshFrame(
      peerId: nodeId,
      data: frame,
    ));
    return true;
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    LoopbackRegistry.unregister(nodeId);
    await _peerDiscoveredController.close();
    await _peerLostController.close();
    await _frameReceivedController.close();
  }
}
