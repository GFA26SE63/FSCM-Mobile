import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/product.dart';

/// LocalProduct + LocalPrice.
class ProductDao {
  ProductDao(this._appDb);

  final AppDatabase _appDb;

  Future<void> replaceProducts(List<Product> items) async {
    final db = await _appDb.database;
    final batch = db.batch()..delete(Tables.product);
    for (final p in items) {
      batch.insert(
        Tables.product,
        <String, Object?>{
          'sku': p.sku,
          'name': p.name,
          'category': p.category,
          'json': jsonEncode(p.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> products() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.product, orderBy: 'sku');
    return rows
        .map((r) => Product.fromJson(asMap(jsonDecode(r['json']! as String))))
        .toList();
  }

  Future<void> replacePrices(List<PriceEntry> items) async {
    final db = await _appDb.database;
    final batch = db.batch()..delete(Tables.price);
    for (final e in items) {
      batch.insert(
        Tables.price,
        <String, Object?>{'sku': e.sku, 'price': e.price},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, int>> prices() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.price);
    return <String, int>{
      for (final r in rows) r['sku']! as String: (r['price']! as num).toInt(),
    };
  }
}
