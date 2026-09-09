import 'dart:async';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';

class OfflineRequestManager {
  static final OfflineRequestManager instance = OfflineRequestManager._internal();
  OfflineRequestManager._internal();

  final Map<String, Completer<OfflinePacket>> _pendingRequests = {};

  /// Check if a request ID is currently pending a response on this device.
  bool isPending(String requestId) {
    return _pendingRequests.containsKey(requestId);
  }

  /// Register a new outgoing request completer.
  void registerRequest(String requestId, Completer<OfflinePacket> completer) {
    _pendingRequests[requestId] = completer;
  }

  /// Resolve a pending request with its received response packet.
  void resolveRequest(String requestId, OfflinePacket response) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  /// Terminate a pending request with a failure/error.
  void failRequest(String requestId, Object error) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  /// Remove a pending request without completing or failing it.
  void removeRequest(String requestId) {
    _pendingRequests.remove(requestId);
  }

  /// Clean up all pending requests.
  void clearAll() {
    for (final id in _pendingRequests.keys.toList()) {
      failRequest(id, TimeoutException('Request cleared'));
    }
    _pendingRequests.clear();
  }
}
