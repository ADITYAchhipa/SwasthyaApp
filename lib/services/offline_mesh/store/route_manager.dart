import 'package:sqflite/sqflite.dart';
import 'package:swasthya_tap/services/offline_mesh/store/mesh_database.dart';

class RouteEntry {
  final String requestId;
  final String previousPeer;
  final String nextPeer;
  final int hops;
  final int expiresAt;

  RouteEntry({
    required this.requestId,
    required this.previousPeer,
    required this.nextPeer,
    required this.hops,
    required this.expiresAt,
  });
}

class RouteManager {
  static final RouteManager instance = RouteManager._internal();
  RouteManager._internal();

  /// Add or update a reverse-routing path.
  Future<void> addRoute({
    required String requestId,
    required String previousPeer,
    required String nextPeer,
    required int hops,
    required int expiresAt,
  }) async {
    final db = await MeshDatabase.instance.database;
    await db.insert(
      'routes',
      {
        'request_id': requestId,
        'previous_peer': previousPeer,
        'next_peer': nextPeer,
        'hops': hops,
        'expires_at': expiresAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve the routing path for a given request.
  Future<RouteEntry?> getRoute(String requestId) async {
    final db = await MeshDatabase.instance.database;
    final results = await db.query(
      'routes',
      where: 'request_id = ?',
      whereArgs: [requestId],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return RouteEntry(
      requestId: row['request_id'] as String,
      previousPeer: row['previous_peer'] as String? ?? '',
      nextPeer: row['next_peer'] as String? ?? '',
      hops: row['hops'] as int,
      expiresAt: row['expires_at'] as int,
    );
  }

  /// Delete the routing path for a request (e.g. once forwarded).
  Future<void> deleteRoute(String requestId) async {
    final db = await MeshDatabase.instance.database;
    await db.delete(
      'routes',
      where: 'request_id = ?',
      whereArgs: [requestId],
    );
  }
}
