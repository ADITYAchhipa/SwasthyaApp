import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:swasthya_tap/services/offline_mesh/mesh_config.dart';
import 'package:swasthya_tap/services/offline_mesh/offline_packet.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_database.dart';

class QueueItem {
  final int id;
  final String requestId;
  final String packetType;
  final OfflinePacket packet;
  final String state; // QUEUED | FORWARDING | FORWARDED | DELIVERED | EXPIRED | FAILED
  final int attempts;
  final List<String> forwardedPeers;
  final int nextAttemptAt;
  final int expiresAt;

  QueueItem({
    required this.id,
    required this.requestId,
    required this.packetType,
    required this.packet,
    required this.state,
    required this.attempts,
    required this.forwardedPeers,
    required this.nextAttemptAt,
    required this.expiresAt,
  });

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    final rawBlob = map['packet_blob'] as String;
    final decodedBlob = jsonDecode(rawBlob) as Map<String, dynamic>;
    final peersStr = map['forwarded_peers'] as String? ?? '';
    final peersList = peersStr.isEmpty ? <String>[] : peersStr.split(',');

    return QueueItem(
      id: map['id'] as int,
      requestId: map['request_id'] as String,
      packetType: map['packet_type'] as String,
      packet: OfflinePacket.fromJson(decodedBlob),
      state: map['state'] as String,
      attempts: map['attempts'] as int,
      forwardedPeers: peersList,
      nextAttemptAt: map['next_attempt_at'] as int,
      expiresAt: map['expires_at'] as int,
    );
  }
}

class MeshQueue {
  static final MeshQueue instance = MeshQueue._internal();
  MeshQueue._internal();

  /// Enqueue an outbound packet for routing.
  Future<void> enqueue(OfflinePacket packet) async {
    final db = await MeshDatabase.instance.database;
    final blob = jsonEncode(packet.toJson());

    await db.insert(
      'mesh_queue',
      {
        'request_id': packet.rid,
        'packet_type': packet.t,
        'packet_blob': blob,
        'state': 'QUEUED',
        'attempts': 0,
        'forwarded_peers': '',
        'next_attempt_at': packet.iat,
        'expires_at': packet.exp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all packets that are due for sending/retrying.
  Future<List<QueueItem>> getPendingPackets() async {
    final db = await MeshDatabase.instance.database;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final results = await db.query(
      'mesh_queue',
      where: '(state = ? OR state = ?) AND next_attempt_at <= ? AND expires_at > ?',
      whereArgs: ['QUEUED', 'FAILED', nowSec, nowSec],
      orderBy: 'next_attempt_at ASC',
    );

    return results.map((m) => QueueItem.fromMap(m)).toList();
  }

  /// Update the status of a queue item.
  Future<void> updateState(int id, String state) async {
    final db = await MeshDatabase.instance.database;
    await db.update(
      'mesh_queue',
      {'state': state},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark a request as successfully completed/delivered, removing it from queue sweeps or updating state.
  Future<void> markDelivered(String requestId) async {
    final db = await MeshDatabase.instance.database;
    await db.update(
      'mesh_queue',
      {'state': 'DELIVERED'},
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }

  /// Record a transmission attempt. Applies exponential retry backoff.
  Future<void> recordAttempt(QueueItem item, {String? sentToPeer}) async {
    final db = await MeshDatabase.instance.database;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final newAttempts = item.attempts + 1;
    final updatedPeersList = List<String>.from(item.forwardedPeers);
    if (sentToPeer != null && !updatedPeersList.contains(sentToPeer)) {
      updatedPeersList.add(sentToPeer);
    }
    final forwardedPeersStr = updatedPeersList.join(',');

    String newState = item.state;
    int nextAttempt = nowSec;

    if (newAttempts >= MeshConfig.maxRetries) {
      newState = 'FAILED';
      nextAttempt = nowSec + 999999; // Don't retry again
    } else {
      // Calculate delay index
      final delayIndex = (newAttempts - 1).clamp(0, MeshConfig.retryDelays.length - 1);
      final delay = MeshConfig.retryDelays[delayIndex];
      nextAttempt = nowSec + delay.inSeconds;
    }

    await db.update(
      'mesh_queue',
      {
        'attempts': newAttempts,
        'forwarded_peers': forwardedPeersStr,
        'next_attempt_at': nextAttempt,
        'state': newState,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Completely remove a request from the queue (e.g. when completed).
  Future<void> remove(String requestId) async {
    final db = await MeshDatabase.instance.database;
    await db.delete(
      'mesh_queue',
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }
}
