import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/promotion.dart';

/// LocalPromotion: promotions used for the offline discount estimate.
class PromotionDao {
  PromotionDao(this._appDb);

  final AppDatabase _appDb;

  Future<void> replaceAll(List<Promotion> items) async {
    final db = await _appDb.database;
    final batch = db.batch()..delete(Tables.promotion);
    for (final p in items) {
      batch.insert(
        Tables.promotion,
        <String, Object?>{
          'id': p.id,
          'active': p.active ? 1 : 0,
          'json': jsonEncode(p.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Promotion>> all() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.promotion, orderBy: 'id');
    return rows
        .map((r) => Promotion.fromJson(asMap(jsonDecode(r['json']! as String))))
        .toList();
  }
}
