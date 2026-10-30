import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/data/local/database_factory.dart';

/// Names of the SQLite tables (SPEC section 11, "Offline").
class Tables {
  Tables._();

  static const String syncState = 'local_sync_state';
  static const String retailer = 'local_retailer';
  static const String product = 'local_product';
  static const String price = 'local_price';
  static const String promotion = 'local_promotion';
  static const String inventorySnapshot = 'local_inventory_snapshot';
  static const String offlineOrderQueue = 'offline_order_queue';
}

/// Opens the local SQLite database and owns its schema migrations.
///
/// To change the schema: add a new entry at the END of [_migrations] (never
/// edit an old one) and bump nothing else - [version] follows the list.
class AppDatabase {
  AppDatabase({this.databaseName = 'fscm_mobile.db'});

  final String databaseName;
  Database? _db;

  /// Schema version = number of migrations.
  static int get version => _migrations.length;

  /// `_migrations[i]` upgrades the schema from version `i` to `i + 1`.
  static final List<List<String>> _migrations = <List<String>>[
    // v1 - initial schema
    <String>[
      '''
CREATE TABLE ${Tables.syncState} (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
      '''
CREATE TABLE ${Tables.retailer} (
  code TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  area_code TEXT NOT NULL,
  json TEXT NOT NULL
)''',
      'CREATE INDEX idx_local_retailer_area ON ${Tables.retailer}(area_code)',
      '''
CREATE TABLE ${Tables.product} (
  sku TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  json TEXT NOT NULL
)''',
      '''
CREATE TABLE ${Tables.price} (
  sku TEXT PRIMARY KEY,
  price INTEGER NOT NULL
)''',
      '''
CREATE TABLE ${Tables.promotion} (
  id TEXT PRIMARY KEY,
  active INTEGER NOT NULL DEFAULT 1,
  json TEXT NOT NULL
)''',
      '''
CREATE TABLE ${Tables.inventorySnapshot} (
  sku TEXT PRIMARY KEY,
  available INTEGER NOT NULL,
  updated_at TEXT NOT NULL
)''',
      '''
CREATE TABLE ${Tables.offlineOrderQueue} (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_request_id TEXT NOT NULL UNIQUE,
  offline_code TEXT NOT NULL,
  payload TEXT NOT NULL,
  status TEXT NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0,
  error TEXT,
  created_at TEXT NOT NULL,
  last_attempt_at TEXT,
  synced_at TEXT,
  server_order_code TEXT,
  sync_mode TEXT,
  final_amount INTEGER,
  promo_changed INTEGER NOT NULL DEFAULT 0,
  change_reason TEXT
)''',
      'CREATE INDEX idx_queue_status ON ${Tables.offlineOrderQueue}(status, id)',
    ],
  ];

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    initDatabaseFactory();
    final path =
        kIsWeb ? databaseName : p.join(await getDatabasesPath(), databaseName);
    return openDatabase(
      path,
      version: version,
      onCreate: (db, v) => _runMigrations(db, 0, v),
      onUpgrade: _runMigrations,
    );
  }

  static Future<void> _runMigrations(Database db, int from, int to) async {
    for (var v = from; v < to; v++) {
      for (final sql in _migrations[v]) {
        await db.execute(sql);
      }
    }
  }

  /// Wipes cached business data (logout). The offline queue is kept only if
  /// [keepQueue] - unsynced orders must never be lost silently.
  Future<void> clearCache({bool keepQueue = true}) async {
    final db = await database;
    final batch = db.batch();
    // The offline order counter survives logout: codes must never repeat.
    batch.delete(
      Tables.syncState,
      where: 'key != ?',
      whereArgs: <Object?>['offline_order_seq'],
    );
    for (final t in <String>[
      Tables.retailer,
      Tables.product,
      Tables.price,
      Tables.promotion,
      Tables.inventorySnapshot,
      if (!keepQueue) Tables.offlineOrderQueue,
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
