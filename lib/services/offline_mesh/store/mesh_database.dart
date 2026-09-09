import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class MeshDatabase {
  static final MeshDatabase instance = MeshDatabase._internal();
  MeshDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'mesh.db');

    return await openDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        // seen_requests table (deduplication cache)
        await db.execute('''
          CREATE TABLE seen_requests (
            request_id TEXT PRIMARY KEY,
            packet_type TEXT,
            first_seen INTEGER,
            expires_at INTEGER,
            completed INTEGER DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_seen_exp ON seen_requests(expires_at)');

        // mesh_queue table (outbound queue)
        await db.execute('''
          CREATE TABLE mesh_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            request_id TEXT,
            packet_type TEXT,
            packet_blob TEXT NOT NULL,
            state TEXT,
            attempts INTEGER DEFAULT 0,
            forwarded_peers TEXT,
            next_attempt_at INTEGER,
            expires_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_queue_state ON mesh_queue(state, next_attempt_at)');

        // routes table (reverse path tracking)
        await db.execute('''
          CREATE TABLE routes (
            request_id TEXT PRIMARY KEY,
            previous_peer TEXT,
            next_peer TEXT,
            hops INTEGER,
            expires_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_routes_exp ON routes(expires_at)');
      },
    );
  }

  /// Sweeps expired packets, routes, and cached requests from the database.
  Future<void> sweepExpired() async {
    final db = await database;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.transaction((txn) async {
      // 1. Delete expired seen_requests
      await txn.delete(
        'seen_requests',
        where: 'expires_at < ?',
        whereArgs: [nowSec],
      );

      // 2. Mark expired queue packets
      await txn.update(
        'mesh_queue',
        {'state': 'EXPIRED'},
        where: 'expires_at < ? AND state != ?',
        whereArgs: [nowSec, 'EXPIRED'],
      );

      // 3. Delete expired routes
      await txn.delete(
        'routes',
        where: 'expires_at < ?',
        whereArgs: [nowSec],
      );
    });
  }

  /// Clear the database completely (useful for tests or full resets).
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('seen_requests');
    await db.delete('mesh_queue');
    await db.delete('routes');
  }
}
