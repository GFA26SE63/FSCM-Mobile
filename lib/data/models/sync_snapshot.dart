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

  factory SyncSnapshot.fromJson(Map<String, dynamic> j) {
    final generatedAt = asDate(j['generatedAt'] ?? j['serverTime']) ?? DateTime.now();
    final productRows = asMapList(j['products']);
    final retailers = mapList(j['retailers'], Retailer.fromJson);
    final skuById = <String, String>{
      for (final product in productRows) asStr(product['id']): asStr(product['sku']),
    };
    final categoryNames = <String, String>{
      for (final category in asMapList(j['categories']))
        asStr(category['id']): asStr(category['name']),
    };
    String skuOf(Map<String, dynamic> row) =>
        asStr(row['sku'], skuById[asStr(row['productId'])] ?? '');

    final priceRows = asMapList(j['prices']);
    priceRows.sort((a, b) =>
        (asDate(a['effectiveFrom']) ?? DateTime(0))
            .compareTo(asDate(b['effectiveFrom']) ?? DateTime(0)));
    final prices = <String, PriceEntry>{};
    for (final row in priceRows) {
      final from = asDate(row['effectiveFrom']);
      final to = asDate(row['effectiveTo']);
      if (!asBool(row['isActive'], true) ||
          (from != null && from.isAfter(generatedAt)) ||
          (to != null && !to.isAfter(generatedAt))) {
        continue;
      }
      final sku = skuOf(row);
      if (sku.isNotEmpty) {
        prices[sku] = PriceEntry(sku: sku, price: asInt(row['unitPrice'] ?? row['price']));
      }
    }
    final products = productRows.map((row) => Product.fromJson({
      ...row,
      'basePrice': prices[asStr(row['sku'])]?.price ?? row['basePrice'],
      'category': row['category'] ?? categoryNames[asStr(row['categoryId'])],
    })).toList();
    final stock = asMapList(j['indicativeStock'] ?? j['stock'])
        .where((row) => skuOf(row).isNotEmpty)
        .map((row) => StockEntry(
          sku: skuOf(row),
          available: asInt(row['indicativeAvailableQuantity'] ?? row['available']),
        )).toList();

    final promotions = asMapList(j['promotions']).map((row) {
      if (!row.containsKey('minimumQuantity')) return Promotion.fromJson(row);
      final productIds = asStrList(row['productIds']);
      final categoryIds = asStrList(row['categoryIds']);
      final retailerIds = asStrList(row['retailerIds']);
      final skus = productRows.where((product) =>
          (productIds.isEmpty && categoryIds.isEmpty) ||
          productIds.contains(asStr(product['id'])) ||
          categoryIds.contains(asStr(product['categoryId'])))
          .map((product) => asStr(product['sku'])).toList();
      return Promotion.fromJson({
        'id': row['id'],
        'name': row['name'],
        'type': 2,
        'validFrom': row['startAt'],
        'validTo': row['endAt'],
        'active': row['isActive'],
        'usesExactTimes': true,
        'groupSkus': skus,
        'groupMinQty': row['minimumQuantity'],
        'groupPct': row['discountPercent'],
        'retailerCodes': retailerIds.isEmpty ? null :
            retailers.where((retailer) => retailerIds.contains(retailer.id))
                .map((retailer) => retailer.code).toList(),
      });
    }).toList();
    return SyncSnapshot(
      serverTime: generatedAt,
      retailers: retailers,
      products: products,
      prices: prices.values.toList(),
      promotions: promotions,
      stock: stock,
      fullReload: asBool(j['fullReload'], true),
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
