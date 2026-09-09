import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:swasthya_tap/services/offline_mesh/device_identity.dart';
import 'package:swasthya_tap/services/offline_mesh/network_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/mesh_transport.dart';

class SimulatedTransport extends MeshTransport {
  static const int _kPort = 4554;
  static final InternetAddress _kBroadcastAddr = InternetAddress('255.255.255.255');

  final _peerDiscoveredController = StreamController<MeshPeer>.broadcast();
  final _peerLostController = StreamController<MeshPeer>.broadcast();
  final _frameReceivedController = StreamController<MeshFrame>.broadcast();

  RawDatagramSocket? _socket;
  Timer? _advertiserTimer;
  bool _isListening = false;
  final Map<String, MeshPeer> _peers = {};

  @override
  String get id => 'simulated';

  @override
  Stream<MeshPeer> get onPeerDiscovered => _peerDiscoveredController.stream;

  @override
  Stream<MeshPeer> get onPeerLost => _peerLostController.stream;

  @override
  Stream<MeshFrame> get onFrameReceived => _frameReceivedController.stream;

  @override
  Future<bool> isAvailable() async => true; // Dev simulation is always available

  @override
  Future<void> startDiscovery({Duration? maxDuration}) async {
    if (_isListening) return;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _kPort, reuseAddress: true, reusePort: true);
      _socket!.broadcastEnabled = true;
      _isListening = true;

      // Start listening for incoming UDP datagrams
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Start periodic advertisement broadcast
      final deviceId = DeviceIdentity.hasInstance ? DeviceIdentity.instance.deviceId : 'unknown';
      final shortId = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;

      _advertiserTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        final hasInternet = await NetworkManager.instance.isInternetAvailable();
        final advMsg = 'adv|$shortId|${hasInternet ? "G" : "R"}';
        _sendUdp(advMsg);
      });
    } catch (_) {
      _isListening = false;
    }

    if (maxDuration != null) {
      Future.delayed(maxDuration, stopDiscovery);
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _advertiserTimer?.cancel();
    _advertiserTimer = null;
    _socket?.close();
    _socket = null;
    _isListening = false;
    _peers.clear();
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final msg = utf8.decode(datagram.data);
      final parts = msg.split('|');
      if (parts.isEmpty) return;

      final prefix = parts[0];
      final senderId = parts[1];

      final myDeviceId = DeviceIdentity.hasInstance ? DeviceIdentity.instance.deviceId : 'unknown';
      final myShortId = myDeviceId.length > 8 ? myDeviceId.substring(0, 8) : myDeviceId;
      if (senderId == myShortId) return; // ignore self

      if (prefix == 'adv') {
        final peerHasInternet = parts.length > 2 && parts[2] == 'G';
        final peer = MeshPeer(
          peerId: senderId,
          transportId: id,
          lastSeen: DateTime.now(),
          state: 'DISCONNECTED',
          advertisedHasInternet: peerHasInternet,
          hopHint: peerHasInternet ? 1 : 2,
        );

        _peers[senderId] = peer;
        _peerDiscoveredController.add(peer);
      } else if (prefix == 'frame') {
        if (parts.length < 4) return;
        final targetId = parts[2];
        final base64Payload = parts[3];

        if (targetId == myShortId) {
          final payload = base64Decode(base64Payload);
          _frameReceivedController.add(MeshFrame(
            peerId: senderId,
            data: payload,
          ));
        }
      }
    } catch (_) {}
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    final peer = _peers[peerId];
    if (peer == null) return false;

    // Simulate successful connection state update
    final connectedPeer = peer.copyWith(state: 'CONNECTED');
    _peers[peerId] = connectedPeer;
    _peerDiscoveredController.add(connectedPeer);
    return true;
  }

  @override
  Future<void> disconnectPeer(String peerId) async {
    final peer = _peers[peerId];
    if (peer == null) return;

    final disconnectedPeer = peer.copyWith(state: 'DISCONNECTED');
    _peers[peerId] = disconnectedPeer;
    _peerLostController.add(disconnectedPeer);
  }

  @override
  Future<bool> sendFrame(String peerId, Uint8List frame) async {
    final myDeviceId = DeviceIdentity.hasInstance ? DeviceIdentity.instance.deviceId : 'unknown';
    final myShortId = myDeviceId.length > 8 ? myDeviceId.substring(0, 8) : myDeviceId;

    final base64Payload = base64Encode(frame);
    final frameMsg = 'frame|$myShortId|$peerId|$base64Payload';
    
    return _sendUdp(frameMsg);
  }

  bool _sendUdp(String msg) {
    if (_socket == null) return false;
    try {
      final bytes = utf8.encode(msg);
      _socket!.send(bytes, _kBroadcastAddr, _kPort);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await _peerDiscoveredController.close();
    await _peerLostController.close();
    await _frameReceivedController.close();
  }
}
