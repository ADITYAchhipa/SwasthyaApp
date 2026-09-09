import 'dart:typed_data';

class MeshPeer {
  final String peerId;
  final String transportId;
  final DateTime lastSeen;
  final int? rssi;
  final String state; // 'DISCONNECTED' | 'CONNECTING' | 'CONNECTED'
  final bool advertisedHasInternet;
  final int hopHint;

  MeshPeer({
    required this.peerId,
    required this.transportId,
    required this.lastSeen,
    this.rssi,
    required this.state,
    required this.advertisedHasInternet,
    required this.hopHint,
  });

  MeshPeer copyWith({
    String? state,
    DateTime? lastSeen,
    bool? advertisedHasInternet,
    int? hopHint,
    int? rssi,
  }) {
    return MeshPeer(
      peerId: peerId,
      transportId: transportId,
      lastSeen: lastSeen ?? this.lastSeen,
      rssi: rssi ?? this.rssi,
      state: state ?? this.state,
      advertisedHasInternet: advertisedHasInternet ?? this.advertisedHasInternet,
      hopHint: hopHint ?? this.hopHint,
    );
  }
}

class MeshFrame {
  final String peerId;
  final Uint8List data;

  MeshFrame({
    required this.peerId,
    required this.data,
  });
}

abstract class MeshTransport {
  String get id; // 'nearby' | 'loopback' | 'simulated'
  
  Future<bool> isAvailable();
  
  Future<void> startDiscovery({Duration? maxDuration});
  
  Future<void> stopDiscovery();
  
  Stream<MeshPeer> get onPeerDiscovered;
  
  Stream<MeshPeer> get onPeerLost;
  
  Future<bool> connectToPeer(String peerId);
  
  Future<void> disconnectPeer(String peerId);
  
  Future<bool> sendFrame(String peerId, Uint8List frame);
  
  Stream<MeshFrame> get onFrameReceived;
  
  Future<void> dispose();
}
