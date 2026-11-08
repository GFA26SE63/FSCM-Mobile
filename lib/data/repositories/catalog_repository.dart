import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';
import 'package:fscm_mobile/data/pricing/promotion_calculator.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

class CatalogData {
  CatalogData({
    required this.retailers,
    required this.products,
    required this.prices,
    required this.promotions,
    required this.stock,
    this.lastSyncAt,
    this.snapshot,
  });

  factory CatalogData.empty() => CatalogData(
        retailers: const [],
        products: const [],
        prices: const {},
        promotions: const [],
        stock: const {},
      );

  factory CatalogData.fromSnapshot(SyncSnapshot snapshot) => CatalogData(
        retailers: snapshot.retailers,
        products: snapshot.products,
        prices: {
          for (final item in snapshot.prices) item.sku: item.price,
        },
        promotions: snapshot.promotions,
        stock: {
          for (final item in snapshot.stock) item.sku: item.available,
        },
        lastSyncAt: snapshot.generatedAt,
        snapshot: snapshot,
      );

  final List<Retailer> retailers;
  final List<Product> products;
  final Map<String, int> prices;
  final List<Promotion> promotions;
  final Map<String, int> stock;
  final DateTime? lastSyncAt;
  final SyncSnapshot? snapshot;

  late final Map<String, Product> productMap = {
    for (final product in products) product.sku: product,
  };

  bool get isEmpty => products.isEmpty && retailers.isEmpty;
  bool get hasSnapshot => snapshot != null;

  String get stockDisclaimer =>
      snapshot?.stockDisclaimer ??
      'Tồn chỉ để tham khảo, không phải hàng đã giữ.';

  String get priceDisclaimer =>
      snapshot?.priceDisclaimer ??
      'Giá chính thức được xác định sau allocation.';

  Product? product(String sku) => productMap[sku];

  Retailer? retailer(String code) {
    for (final retailer in retailers) {
      if (retailer.code == code) return retailer;
    }

    return null;
  }

  // Các getter cũ còn được màn tạo đơn sử dụng.
  // Chúng không đại diện cho kết quả allocation chính thức.
  int unitPrice(String sku) => prices[sku] ?? productMap[sku]?.basePrice ?? 0;

  int available(String sku) => stock[sku] ?? 0;

  int maxQty(String sku) => OrderLimits.maxQty(available(sku));

  num? displayPrice(Product product) =>
      snapshot?.priceForProduct(product.id, AppClock.now());

  num? displayStock(Product product) => snapshot?.stockForProduct(product.id);

  List<Promotion> runningPromotions({String? retailerCode}) {
    final now = AppClock.now();

    return promotions.where((promotion) {
      if (!promotion.active) return false;

      if (promotion.validFrom != null && now.isBefore(promotion.validFrom!)) {
        return false;
      }

      if (promotion.validTo != null && now.isAfter(promotion.validTo!)) {
        return false;
      }

      return retailerCode == null || promotion.appliesTo(retailerCode);
    }).toList();
  }

  String promotionCode(Promotion promotion) =>
      snapshot?.promotionCode(promotion.id) ?? promotion.id;

  Map<String, dynamic>? promotionRecord(Promotion promotion) =>
      snapshot?.promotionRecord(promotion.id);

  PriceQuote quote(
    List<CartLine> lines,
    String retailerCode, {
    DateTime? now,
  }) {
    final at = now ?? AppClock.now();
    final effectivePrices = <String, num>{};

    for (final product in products) {
      final num? price = snapshot != null
          ? snapshot!.priceForProduct(product.id, at)
          : prices[product.sku];

      if (price != null) {
        effectivePrices[product.sku] = price;
      }
    }

    return PromotionCalculator.quote(
      lines: lines,
      retailerCode: retailerCode,
      promotions: promotions,
      products: productMap,
      prices: effectivePrices,
      promotionCodes: {
        for (final promotion in promotions)
          promotion.id: promotionCode(promotion),
      },
      now: at,
    );
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final ownerId = ref.watch(currentUserProvider)?.id ?? '';

  return CatalogRepository(
    database: ref.watch(appDatabaseProvider),
    ownerId: ownerId,
    isCurrentUser: () => (ref.read(currentUserProvider)?.id ?? '') == ownerId,
  );
});

final catalogProvider = FutureProvider<CatalogData>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);

  return ref.watch(catalogRepositoryProvider).load();
});

class CatalogRepository {
  CatalogRepository({
    required AppDatabase database,
    required String ownerId,
    required bool Function() isCurrentUser,
  })  : _database = database,
        _ownerId = ownerId,
        _isCurrentUser = isCurrentUser;

  static const cacheKey = 'catalog_snapshot_contract_v2';

  final AppDatabase _database;
  final String _ownerId;
  final bool Function() _isCurrentUser;

  Future<CatalogData> load() async {
    if (_ownerId.isEmpty || !_isCurrentUser()) {
      return CatalogData.empty();
    }

    final db = await _database.database;
    final rows = await db.query(
      Tables.syncState,
      where: 'key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (rows.isEmpty) return CatalogData.empty();

    final envelope = asMap(
      jsonDecode(rows.first['value']! as String),
    );

    if (envelope['ownerId'] != _ownerId || !_isCurrentUser()) {
      return CatalogData.empty();
    }

    final snapshot = SyncSnapshot.fromJson(
      asMap(envelope['snapshot']),
    );

    return CatalogData.fromSnapshot(snapshot);
  }

  Future<void> applySnapshot(SyncSnapshot snapshot) async {
    _ensureCurrentUser();

    final db = await _database.database;
    final updatedAt = AppClock.now().toUtc().toIso8601String();

    await db.transaction((transaction) async {
      _ensureCurrentUser();

      final batch = transaction.batch();

      for (final table in [
        Tables.retailer,
        Tables.product,
        Tables.price,
        Tables.promotion,
        Tables.inventorySnapshot,
      ]) {
        batch.delete(table);
      }

      for (final retailer in snapshot.retailers) {
        batch.insert(
          Tables.retailer,
          {
            'code': retailer.code,
            'name': retailer.name,
            'area_code': retailer.areaCode,
            'json': jsonEncode(retailer.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final product in snapshot.products) {
        batch.insert(
          Tables.product,
          {
            'sku': product.sku,
            'name': product.name,
            'category': product.category,
            'json': jsonEncode(product.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final price in snapshot.prices) {
        batch.insert(
          Tables.price,
          {
            'sku': price.sku,
            'price': price.price,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final promotion in snapshot.promotions) {
        batch.insert(
          Tables.promotion,
          {
            'id': promotion.id,
            'active': promotion.active ? 1 : 0,
            'json': jsonEncode(promotion.toJson()),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final item in snapshot.stock) {
        batch.insert(
          Tables.inventorySnapshot,
          {
            'sku': item.sku,
            'available': item.available,
            'updated_at': updatedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      batch.insert(
        Tables.syncState,
        {
          'key': cacheKey,
          'value': jsonEncode({
            'ownerId': _ownerId,
            'snapshot': snapshot.toJson(),
          }),
          'updated_at': updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      batch.insert(
        Tables.syncState,
        {
          'key': SyncStateDao.keyLastSync,
          'value': snapshot.generatedAt.toUtc().toIso8601String(),
          'updated_at': updatedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _ensureCurrentUser();

      await batch.commit(noResult: true);

      // Throw trong transaction sẽ rollback nếu phiên đã đổi.
      _ensureCurrentUser();
    });
  }

  void _ensureCurrentUser() {
    if (_ownerId.isEmpty || !_isCurrentUser()) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu.',
      );
    }
  }
}
