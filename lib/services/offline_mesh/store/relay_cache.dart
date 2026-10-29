import 'package:sqflite/sqflite.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_database.dart';

class RelayCache {
  static final RelayCache instance = RelayCache._internal();
  RelayCache._internal();

  /// Check if a request has been seen before.
  Future<bool> contains(String requestId, String packetType) async {
    final db = await MeshDatabase.instance.database;
    final results = await db.query(
      'seen_requests',
      where: 'request_id = ?',
      whereArgs: ['$packetType:$requestId'],
    );
    return results.isNotEmpty;
  }

  /// Add a request to the seen requests cache.
  Future<void> addSeenRequest({
    required String requestId,
    required String packetType,
    required int expiresAt,
  }) async {
    final db = await MeshDatabase.instance.database;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await db.insert(
      'seen_requests',
      {
        'request_id': '$packetType:$requestId',
        'packet_type': packetType,
        'first_seen': nowSec,
        'expires_at': expiresAt,
        'completed': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Mark a request or response as successfully completed/delivered.
  Future<void> markCompleted(String requestId, String packetType) async {
    final db = await MeshDatabase.instance.database;
    await db.update(
      'seen_requests',
      {'completed': 1},
      where: 'request_id = ?',
      whereArgs: ['$packetType:$requestId'],
    );
  }

  /// Check if the request or response has been marked completed.
  Future<bool> isCompleted(String requestId, String packetType) async {
    final db = await MeshDatabase.instance.database;
    final results = await db.query(
      'seen_requests',
      columns: ['completed'],
      where: 'request_id = ?',
      whereArgs: ['$packetType:$requestId'],
    );
    if (results.isEmpty) return false;
    return (results.first['completed'] as int) == 1;
  }
}
