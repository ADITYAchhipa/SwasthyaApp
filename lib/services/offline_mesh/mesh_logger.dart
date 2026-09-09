import 'package:flutter/foundation.dart';

class MeshLogger {
  static const Set<String> _kAllowList = {
    'requestId',
    'packetType',
    'ttl',
    'status',
    'peerIdHash',
    'transportId',
    'errorCode',
    'durationMs',
    'hopCount',
  };

  /// Log structured mesh event. Only allow-listed keys are logged.
  static void log(Map<String, dynamic> event) {
    final Map<String, dynamic> filtered = {};
    for (final entry in event.entries) {
      if (_kAllowList.contains(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    
    // Print the structured log
    debugPrint('[mesh] $filtered');
  }

  /// Convenience log helpers
  static void logError(String errorCode, {String? requestId, String? transportId}) {
    log({
      'status': 'error',
      'errorCode': errorCode,
      if (requestId != null) 'requestId': requestId,
      if (transportId != null) 'transportId': transportId,
    });
  }
}
