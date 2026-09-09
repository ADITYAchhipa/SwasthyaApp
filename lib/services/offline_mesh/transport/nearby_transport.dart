import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:swasthya_tap/services/offline_mesh/device_identity.dart';
import 'package:swasthya_tap/services/offline_mesh/network_manager.dart';
import 'package:swasthya_tap/services/offline_mesh/transport/mesh_transport.dart';

class NearbyTransport extends MeshTransport {
  static const String _kServiceId = 'in.swasthyatap.mesh.v1';

  final _peerDiscoveredController = StreamController<MeshPeer>.broadcast();
  final _peerLostController = StreamController<MeshPeer>.broadcast();
  final _frameReceivedController = StreamController<MeshFrame>.broadcast();

  bool _isDiscovering = false;
  bool _isAdvertising = false;

  @override
  String get id => 'nearby';

  @override
  Stream<MeshPeer> get onPeerDiscovered => _peerDiscoveredController.stream;

  @override
  Stream<MeshPeer> get onPeerLost => _peerLostController.stream;

  @override
  Stream<MeshFrame> get onFrameReceived => _frameReceivedController.stream;

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    return await NetworkManager.instance.isNearbyTransportAvailable();
  }

  @override
  Future<void> startDiscovery({Duration? maxDuration}) async {
    if (!Platform.isAndroid) return;
    if (_isDiscovering) return;

    final hasInternet = await NetworkManager.instance.isInternetAvailable();
    final deviceId = DeviceIdentity.hasInstance ? DeviceIdentity.instance.deviceId : 'unknown';
    final shortId = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
    final advName = '$shortId|${hasInternet ? "G" : "R"}';

    // Start advertising
    try {
      _isAdvertising = await Nearby().startAdvertising(
        advName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _kServiceId,
      );
    } catch (_) {
      _isAdvertising = false;
    }

    // Start discovery
    try {
      _isDiscovering = await Nearby().startDiscovery(
        advName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          final parts = endpointName.split('|');
          final peerHasInternet = parts.length > 1 && parts[1] == 'G';
          
          final peer = MeshPeer(
            peerId: endpointId,
            transportId: id,
            lastSeen: DateTime.now(),
            state: 'DISCONNECTED',
            advertisedHasInternet: peerHasInternet,
            hopHint: peerHasInternet ? 1 : 2,
          );
          _peerDiscoveredController.add(peer);
        },
        onEndpointLost: (endpointId) {
          final peer = MeshPeer(
            peerId: endpointId ?? '',
            transportId: id,
            lastSeen: DateTime.now(),
            state: 'DISCONNECTED',
            advertisedHasInternet: false,
            hopHint: 99,
          );
          _peerLostController.add(peer);
        },
        serviceId: _kServiceId,
      );
    } catch (_) {
      _isDiscovering = false;
    }

    if (maxDuration != null) {
      Future.delayed(maxDuration, stopDiscovery);
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!Platform.isAndroid) return;
    
    if (_isDiscovering) {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
    }
    if (_isAdvertising) {
      await Nearby().stopAdvertising();
      _isAdvertising = false;
    }
  }

  @override
  Future<bool> connectToPeer(String peerId) async {
    if (!Platform.isAndroid) return false;
    final deviceId = DeviceIdentity.hasInstance ? DeviceIdentity.instance.deviceId : 'unknown';
    final shortId = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
    final hasInternet = await NetworkManager.instance.isInternetAvailable();
    final advName = '$shortId|${hasInternet ? "G" : "R"}';

    try {
      await Nearby().requestConnection(
        advName,
        peerId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnectPeer(String peerId) async {
    if (!Platform.isAndroid) return;
    try {
      await Nearby().disconnectFromEndpoint(peerId);
    } catch (_) {}
  }

  @override
  Future<bool> sendFrame(String peerId, Uint8List frame) async {
    if (!Platform.isAndroid) return false;
    try {
      await Nearby().sendBytesPayload(peerId, frame);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    // Auto-accept connections in our mesh
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _frameReceivedController.add(MeshFrame(
            peerId: endpointId,
            data: payload.bytes!,
          ));
        }
      },
      onPayloadTransferUpdate: (endpointId, transferUpdate) {
        // Handled if we need progress updates
      },
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      final peer = MeshPeer(
        peerId: endpointId,
        transportId: id,
        lastSeen: DateTime.now(),
        state: 'CONNECTED',
        advertisedHasInternet: false, // will be updated based on discovery metadata
        hopHint: 2,
      );
      _peerDiscoveredController.add(peer);
    } else {
      final peer = MeshPeer(
        peerId: endpointId,
        transportId: id,
        lastSeen: DateTime.now(),
        state: 'DISCONNECTED',
        advertisedHasInternet: false,
        hopHint: 99,
      );
      _peerLostController.add(peer);
    }
  }

  void _onDisconnected(String endpointId) {
    final peer = MeshPeer(
      peerId: endpointId,
      transportId: id,
      lastSeen: DateTime.now(),
      state: 'DISCONNECTED',
      advertisedHasInternet: false,
      hopHint: 99,
    );
    _peerLostController.add(peer);
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    await _peerDiscoveredController.close();
    await _peerLostController.close();
    await _frameReceivedController.close();
  }
}
