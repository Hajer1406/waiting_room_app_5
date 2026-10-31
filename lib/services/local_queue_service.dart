// lib/services/local_queue_service.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Manages local SQLite storage for the waiting room queue.
/// Enables offline-first behavior: data is saved locally first,
/// then synced to Supabase when internet is available.
/// Includes an in-memory fallback for platforms like Web where sqflite is not available.
class LocalQueueService {
  // Static singleton so the DB is only opened once per app lifecycle
  static Database? _database;
  static const String tableName = 'local_clients';

  final bool _inMemory;
  bool _useFallback = kIsWeb;
  final List<Map<String, dynamic>> _fallbackStore = [];

  LocalQueueService({bool inMemory = false}) : _inMemory = inMemory;

  /// Returns the database, initializing it if necessary.
  Future<Database?> get database async {
    if (_useFallback) return null;
    if (_database != null && !_inMemory) return _database!;
    try {
      _database = await _initDB();
      return _database!;
    } catch (e) {
      debugPrint('LocalQueueService: SQLite init error ($e). Using in-memory fallback.');
      _useFallback = true;
      return null;
    }
  }

  Future<Database> _initDB() async {
    if (_inMemory) {
      // Used only in tests: fast, isolated, no disk I/O
      return await openDatabase(
        ':memory:',
        version: 1,
        onCreate: _onCreate,
      );
    } else {
      // Production: persist in app's database directory
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'waiting_room.db');
      return openDatabase(path, version: 1, onCreate: _onCreate);
    }
  }

  /// Creates the table schema on first launch.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Inserts or replaces a client record locally.
  /// Call this immediately when user adds a client (no internet needed).
  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    final db = await database;
    if (db == null) {
      _fallbackStore.removeWhere((item) => item['id'] == client['id']);
      _fallbackStore.add(Map<String, dynamic>.from(client));
      return;
    }
    await db.insert(
      tableName,
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns ALL clients, ordered from first to last (queue order).
  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await database;
    if (db == null) {
      final list = List<Map<String, dynamic>>.from(_fallbackStore);
      list.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
      return list;
    }
    return db.query(tableName, orderBy: 'created_at ASC');
  }

  /// Returns only clients not yet sent to Supabase (is_synced = 0).
  /// Used by _syncLocalToRemote() to know what to upload.
  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    final db = await database;
    if (db == null) {
      return _fallbackStore.where((item) => item['is_synced'] == 0).toList();
    }
    return db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
  }

  /// Marks a client as successfully synced to Supabase.
  Future<void> markClientAsSynced(String id) async {
    final db = await database;
    if (db == null) {
      final index = _fallbackStore.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        _fallbackStore[index]['is_synced'] = 1;
      }
      return;
    }
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes a client from the local DB.
  Future<void> deleteClient(String id) async {
    final db = await database;
    if (db == null) {
      _fallbackStore.removeWhere((item) => item['id'] == id);
      return;
    }
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Closes the database connection. Important for in-memory test isolation.
  Future<void> close() async {
    _fallbackStore.clear();
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
