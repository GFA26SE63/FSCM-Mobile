import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/local/app_database.dart';

/// LocalSyncState: small key/value table (last sync time, offline order
/// counter, locally generated notifications...).
class SyncStateDao {
  SyncStateDao(this._appDb);

  final AppDatabase _appDb;

  static const String keyLastSync = 'last_snapshot_at';
  static const String keyOfflineSeq = 'offline_order_seq';
  static const String keyLocalNotifications = 'local_notifications';

  Future<String?> get(String key) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.syncState,
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _appDb.database;
    await db.insert(
      Tables.syncState,
      <String, Object?>{
        'key': key,
        'value': value,
        'updated_at': AppDates.iso(AppClock.now()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String key) async {
    final db = await _appDb.database;
    await db
        .delete(Tables.syncState, where: 'key = ?', whereArgs: <Object?>[key]);
  }

  Future<DateTime?> lastSyncAt() async =>
      AppDates.tryParse(await get(keyLastSync));

  Future<void> setLastSyncAt(DateTime value) =>
      set(keyLastSync, AppDates.iso(value));

  /// Next number for `OFF-{device}-{0000}`; atomic and never reused.
  Future<int> nextOfflineSeq() async {
    final db = await _appDb.database;
    return db.transaction<int>((txn) async {
      final rows = await txn.query(
        Tables.syncState,
        where: 'key = ?',
        whereArgs: <Object?>[keyOfflineSeq],
        limit: 1,
      );
      final current = rows.isEmpty
          ? 0
          : int.tryParse(rows.first['value'] as String? ?? '') ?? 0;
      final next = current + 1;
      await txn.insert(
        Tables.syncState,
        <String, Object?>{
          'key': keyOfflineSeq,
          'value': next.toString(),
          'updated_at': AppDates.iso(AppClock.now()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return next;
    });
  }
}
