import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/retailer.dart';

/// LocalRetailer: retailers of the Sales' area cached for offline use.
class RetailerDao {
  RetailerDao(this._appDb);

  final AppDatabase _appDb;

  Future<void> replaceAll(List<Retailer> items) async {
    final db = await _appDb.database;
    final batch = db.batch()..delete(Tables.retailer);
    for (final r in items) {
      batch.insert(
        Tables.retailer,
        <String, Object?>{
          'code': r.code,
          'name': r.name,
          'area_code': r.areaCode,
          'json': jsonEncode(r.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Retailer>> all() async {
    final db = await _appDb.database;
    final rows =
        await db.query(Tables.retailer, orderBy: 'name COLLATE NOCASE');
    return rows.map(_fromRow).toList();
  }

  Future<Retailer?> byCode(String code) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.retailer,
      where: 'code = ?',
      whereArgs: <Object?>[code],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Retailer _fromRow(Map<String, Object?> row) =>
      Retailer.fromJson(asMap(jsonDecode(row['json']! as String)));
}
