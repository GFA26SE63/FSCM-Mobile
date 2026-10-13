import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/local/daos/inventory_snapshot_dao.dart';
import 'package:fscm_mobile/data/local/daos/product_dao.dart';
import 'package:fscm_mobile/data/local/daos/promotion_dao.dart';
import 'package:fscm_mobile/data/local/daos/retailer_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
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

/// Everything cached for offline use, loaded from the LocalXxx tables.
class CatalogData {
  CatalogData({
    required this.retailers,
    required this.products,
    required this.prices,
    required this.promotions,
    required this.stock,
    this.lastSyncAt,
  });

  final List<Retailer> retailers;
  final List<Product> products;
  final Map<String, int> prices;
  final List<Promotion> promotions;
  final Map<String, int> stock;
  final DateTime? lastSyncAt;

  late final Map<String, Product> productMap = <String, Product>{
    for (final p in products) p.sku: p,
  };

  bool get isEmpty => products.isEmpty && retailers.isEmpty;

  Product? product(String sku) => productMap[sku];

  Retailer? retailer(String code) {
    for (final r in retailers) {
      if (r.code == code) return r;
    }
    return null;
  }

  int unitPrice(String sku) => prices[sku] ?? productMap[sku]?.basePrice ?? 0;

  int available(String sku) => stock[sku] ?? 0;

  /// Max cartons orderable for [sku] (available - safety buffer, step 10).
  int maxQty(String sku) => OrderLimits.maxQty(available(sku));

  /// Promotions running today that apply to [retailerCode] (all if null).
  List<Promotion> runningPromotions({String? retailerCode}) {
    final now = AppClock.now();
    return promotions
        .where((p) =>
            p.isRunning(now) &&
            (retailerCode == null || p.appliesTo(retailerCode)))
        .toList();
  }

  /// Local estimate used when offline (the server result is final).
  PriceQuote quote(List<CartLine> lines, String retailerCode) =>
      PromotionCalculator.quote(
        lines: lines,
        retailerCode: retailerCode,
        promotions: promotions,
        products: productMap,
        prices: prices,
      );
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    retailers: ref.watch(retailerDaoProvider),
    products: ref.watch(productDaoProvider),
    promotions: ref.watch(promotionDaoProvider),
    inventory: ref.watch(inventorySnapshotDaoProvider),
    syncState: ref.watch(syncStateDaoProvider),
  );
});

/// Cached catalog; reloads after every sync and when the user changes.
final catalogProvider = FutureProvider<CatalogData>((ref) async {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(catalogRepositoryProvider).load();
});

class CatalogRepository {
  CatalogRepository({
    required RetailerDao retailers,
    required ProductDao products,
    required PromotionDao promotions,
    required InventorySnapshotDao inventory,
    required SyncStateDao syncState,
  })  : _retailers = retailers,
        _products = products,
        _promotions = promotions,
        _inventory = inventory,
        _syncState = syncState;

  final RetailerDao _retailers;
  final ProductDao _products;
  final PromotionDao _promotions;
  final InventorySnapshotDao _inventory;
  final SyncStateDao _syncState;

  Future<CatalogData> load() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _retailers.all(),
      _products.products(),
      _products.prices(),
      _promotions.all(),
      _inventory.all(),
      _syncState.lastSyncAt(),
    ]);
    return CatalogData(
      retailers: results[0]! as List<Retailer>,
      products: results[1]! as List<Product>,
      prices: results[2]! as Map<String, int>,
      promotions: results[3]! as List<Promotion>,
      stock: results[4]! as Map<String, int>,
      lastSyncAt: results[5] as DateTime?,
    );
  }

  /// Replaces the local tables with a downloaded snapshot.
  Future<void> applySnapshot(SyncSnapshot s) async {
    await _retailers.replaceAll(s.retailers);
    await _products.replaceProducts(s.products);
    await _products.replacePrices(s.prices);
    await _promotions.replaceAll(s.promotions);
    await _inventory.replaceAll(s.stock);
    await _syncState.setLastSyncAt(s.serverTime);
  }
}
