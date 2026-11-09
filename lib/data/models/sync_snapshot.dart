import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/data/models/retailer.dart';

/// Response of `GET /sync/snapshot?since=` (SPEC section 8): everything the
/// Sales app needs offline.
class SyncSnapshot {
  const SyncSnapshot({
    required this.serverTime,
    required this.retailers,
    required this.products,
    required this.prices,
    required this.promotions,
    required this.stock,
    this.fullReload = true,
  });

  factory SyncSnapshot.fromJson(Map<String, dynamic> j) => SyncSnapshot(
        serverTime: asDate(j['serverTime']) ?? DateTime.now(),
        retailers: mapList(j['retailers'], Retailer.fromJson),
        products: mapList(j['products'], Product.fromJson),
        prices: mapList(j['prices'], PriceEntry.fromJson),
        promotions: mapList(j['promotions'], Promotion.fromJson),
        stock: mapList(j['stock'], StockEntry.fromJson),
        fullReload: asBool(j['fullReload'], true),
      );

  factory SyncSnapshot.fromBackendJson(Map<String, dynamic> j) {
    final now = asDate(j['generatedAt']) ?? DateTime.now();
    final products = asMapList(j['products']);
    final retailers = asMapList(j['retailers']);
    final categories = {
      for (final c in asMapList(j['categories']))
        asStr(c['id']): asStr(c['name'])
    };
    final productById = {for (final p in products) asStr(p['id']): p};
    final retailerById = {
      for (final r in retailers) asStr(r['id']): asStr(r['code'])
    };
    final prices = <String, Map<String, dynamic>>{};
    for (final p in asMapList(j['prices'])) {
      final from = asDate(p['effectiveFrom']);
      final to = asDate(p['effectiveTo']);
      if (!asBool(p['isActive'], true) ||
          from == null ||
          from.isAfter(now) ||
          (to != null && !to.isAfter(now))) {
        continue;
      }
      final id = asStr(p['productId']);
      final old = prices[id];
      if (old == null || from.isAfter(asDate(old['effectiveFrom'])!)) {
        prices[id] = p;
      }
    }
    return SyncSnapshot(
      serverTime: now,
      retailers: retailers
          .map((r) =>
              Retailer.fromJson({...r, 'creditTerm': r['creditTermDays']}))
          .toList(),
      products: products
          .map((p) => Product.fromJson({
                ...p,
                'pack': p['unit'],
                'category': categories[asStr(p['categoryId'])],
                'shelfLifeDays': (asInt(p['shelfLifeHours']) / 24).ceil(),
                'basePrice': prices[asStr(p['id'])]?['unitPrice'] ?? 0
              }))
          .toList(),
      prices: prices.entries
          .where((p) => productById.containsKey(p.key))
          .map((p) => PriceEntry(
              sku: asStr(productById[p.key]!['sku']),
              price: asInt(p.value['unitPrice'])))
          .toList(),
      stock: asMapList(j['indicativeStock'])
          .where((p) => productById.containsKey(asStr(p['productId'])))
          .map((p) => StockEntry(
              sku: asStr(productById[asStr(p['productId'])]!['sku']),
              available: asInt(p['indicativeAvailableQuantity'])))
          .toList(),
      promotions: asMapList(j['promotions'])
          .where((p) => p['type'] == 'Campaign')
          .map((p) {
        final ids = asStrList(p['productIds']).toSet();
        final categoryIds = asStrList(p['categoryIds']).toSet();
        final targets = products.where((x) =>
            ids.contains(asStr(x['id'])) ||
            categoryIds.contains(asStr(x['categoryId'])));
        final retailerIds = asStrList(p['retailerIds']);
        return Promotion(
            id: asStr(p['id']),
            name: asStr(p['name']),
            type: 1,
            validFrom: asDate(p['startAt']),
            validTo: asDate(p['endAt']),
            active: asBool(p['isActive']),
            retailerCodes: retailerIds.isEmpty
                ? null
                : retailerIds
                    .map((id) => retailerById[id] ?? '')
                    .where((code) => code.isNotEmpty)
                    .toList(),
            rules: targets
                .map((x) => PromoRule(
                    sku: asStr(x['sku']),
                    minQty: asInt(p['minimumQuantity']),
                    pct: asDouble(p['discountPercent'])))
                .toList());
      }).toList(),
    );
  }

  final DateTime serverTime;
  final List<Retailer> retailers;
  final List<Product> products;
  final List<PriceEntry> prices;
  final List<Promotion> promotions;
  final List<StockEntry> stock;

  /// When true the local tables are replaced, otherwise rows are upserted.
  final bool fullReload;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'serverTime': isoOrNull(serverTime),
        'retailers': retailers.map((r) => r.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'prices': prices.map((p) => p.toJson()).toList(),
        'promotions': promotions.map((p) => p.toJson()).toList(),
        'stock': stock.map((s) => s.toJson()).toList(),
        'fullReload': fullReload,
      };
}
