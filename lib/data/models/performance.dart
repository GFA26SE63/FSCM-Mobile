import 'package:fscm_mobile/data/models/json_utils.dart';

class RetailerRevenue {
  const RetailerRevenue({
    required this.retailerCode,
    required this.retailerName,
    required this.orders,
    required this.revenueAfterPromo,
  });

  factory RetailerRevenue.fromJson(Map<String, dynamic> j) => RetailerRevenue(
        retailerCode: asStr(j['retailerCode']),
        retailerName: asStr(j['retailerName']),
        orders: asInt(j['orders']),
        revenueAfterPromo: asInt(j['revenueAfterPromo']),
      );

  final String retailerCode;
  final String retailerName;
  final int orders;
  final int revenueAfterPromo;
}

/// Response of `GET /kpi/sales?from=&to=`. Revenue after promotion counts
/// only orders closed by this Sales (SPEC section 4, Performance).
class SalesKpi {
  const SalesKpi({
    required this.periodLabel,
    required this.orderCount,
    required this.revenue,
    required this.revenueAfterPromo,
    required this.byRetailer,
    this.target = 0,
  });

  factory SalesKpi.fromJson(Map<String, dynamic> j) => SalesKpi(
        periodLabel: asStr(j['periodLabel']),
        orderCount: asInt(j['orderCount']),
        revenue: asInt(j['revenue']),
        revenueAfterPromo: asInt(j['revenueAfterPromo']),
        target: asInt(j['target']),
        byRetailer: mapList(j['byRetailer'], RetailerRevenue.fromJson),
      );

  final String periodLabel;
  final int orderCount;
  final int revenue;
  final int revenueAfterPromo;
  final int target;
  final List<RetailerRevenue> byRetailer;

  int get promoGap => revenue - revenueAfterPromo;
  double get progress =>
      target <= 0 ? 0 : (revenueAfterPromo / target).clamp(0.0, 1.0);
}

class RankingEntry {
  const RankingEntry({
    required this.rank,
    required this.name,
    required this.group,
    required this.revenue,
    required this.revenueAfterPromo,
    this.isMe = false,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
        rank: asInt(j['rank']),
        name: asStr(j['name']),
        group: asStr(j['group']),
        revenue: asInt(j['revenue']),
        revenueAfterPromo: asInt(j['revenueAfterPromo']),
        isMe: asBool(j['isMe']),
      );

  final int rank;
  final String name;
  final String group;
  final int revenue;
  final int revenueAfterPromo;
  final bool isMe;
}

class ProductRanking {
  const ProductRanking({
    required this.sku,
    required this.name,
    required this.qty,
    required this.revenueAfterPromo,
  });

  factory ProductRanking.fromJson(Map<String, dynamic> j) => ProductRanking(
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        qty: asInt(j['qty']),
        revenueAfterPromo: asInt(j['revenueAfterPromo']),
      );

  final String sku;
  final String name;
  final int qty;
  final int revenueAfterPromo;
}
