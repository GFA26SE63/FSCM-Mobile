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
