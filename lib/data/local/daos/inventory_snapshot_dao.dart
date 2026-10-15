import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/product.dart';

/// LocalInventorySnapshot: available cartons per SKU at the last sync.
/// Offline orders deduct from it locally so the Sales cannot oversell the
/// cached stock.
class InventorySnapshotDao {
  InventorySnapshotDao(this._appDb);

  final AppDatabase _appDb;

  Future<void> replaceAll(List<StockEntry> items) async {
    final db = await _appDb.database;
    final now = AppDates.iso(AppClock.now());
    final batch = db.batch()..delete(Tables.inventorySnapshot);
    for (final e in items) {
      batch.insert(
        Tables.inventorySnapshot,
        <String, Object?>{
          'sku': e.sku,
          'available': e.available,
          'updated_at': now
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, int>> all() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.inventorySnapshot);
    return <String, int>{
      for (final r in rows)
        r['sku']! as String: (r['available']! as num).toInt(),
    };
  }

  /// Subtracts [qty] cartons (never below zero).
  Future<void> deduct(String sku, int qty) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      'UPDATE ${Tables.inventorySnapshot} '
      'SET available = MAX(0, available - ?) WHERE sku = ?',
      <Object?>[qty, sku],
    );
  }
}
