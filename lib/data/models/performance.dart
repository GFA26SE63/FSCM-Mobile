import 'package:fscm_mobile/core/network/api_exception.dart';

/// Reporting uses inclusive Vietnam calendar dates, independent of device zone.
class PerformancePeriod {
  const PerformancePeriod(this.fromDate, this.toDate);
  final String fromDate;
  final String toDate;

  factory PerformancePeriod.forKey(String key, DateTime now) {
    final vn = now.toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(vn.year, vn.month, vn.day);
    final DateTime start;
    var end = today;
    switch (key) {
      case 'today':
        start = today;
        break;
      case 'week':
        start = today.subtract(const Duration(days: 6));
        break;
      case 'month':
        start = DateTime.utc(vn.year, vn.month);
        break;
      case 'lastMonth':
        start = DateTime.utc(vn.year, vn.month - 1);
        end = DateTime.utc(vn.year, vn.month, 0);
        break;
      case 'quarter':
        start = DateTime.utc(vn.year, ((vn.month - 1) ~/ 3) * 3 + 1);
        break;
      default:
        throw ArgumentError.value(key, 'period');
    }
    String date(DateTime d) => d.toIso8601String().substring(0, 10);
    return PerformancePeriod(date(start), date(end));
  }

  Map<String, dynamic> get query => {'fromDate': fromDate, 'toDate': toDate};
}

Never invalidPerformanceResponse() => throw const ApiException(
    kind: ApiErrorKind.server,
    message: 'Phản hồi báo cáo thiếu dữ liệu hoặc không hợp lệ.');

String reportText(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is! String || value.isEmpty) {
    invalidPerformanceResponse();
  }
  return value;
}

num reportNumber(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is! num || !value.isFinite) {
    invalidPerformanceResponse();
  }
  return value;
}

List<T> reportRows<T>(Map<String, dynamic> j, String key,
    T Function(Map<String, dynamic>) parse) {
  final value = j[key];
  if (value is! List<dynamic>) {
    invalidPerformanceResponse();
  }
  return value.map((row) {
    if (row is! Map<String, dynamic>) {
      invalidPerformanceResponse();
    }
    return parse(row);
  }).toList(growable: false);
}

class PerformanceReport<T> {
  PerformanceReport.fromJson(Map<String, dynamic> j,
      T Function(Map<String, dynamic>) parse, this.loadedAt)
      : fromDate = reportText(j, 'fromDate'),
        toDate = reportText(j, 'toDate'),
        scope = reportText(j, 'scope'),
        entries = reportRows(j, 'entries', parse);
  final String fromDate;
  final String toDate;
  final String scope;

  /// Client receipt time; the API does not expose a report-generated timestamp.
  final DateTime loadedAt;
  final List<T> entries;
}

class KpiMetric {
  KpiMetric.fromJson(Map<String, dynamic> j)
      : code = reportText(j, 'code'),
        name = reportText(j, 'name'),
        target = reportNumber(j, 'target'),
        actual = reportNumber(j, 'actual'),
        completionRate = reportNumber(j, 'completionRate'),
        weight = reportNumber(j, 'weight'),
        weightedScore = reportNumber(j, 'weightedScore'),
        unit = reportText(j, 'unit');
  final String code, name, unit;
  final num target, actual, completionRate, weight, weightedScore;
}

class KpiOrder {
  KpiOrder.fromJson(Map<String, dynamic> j)
      : id = reportText(j, 'orderId'),
        code = reportText(j, 'orderCode'),
        retailerId = reportText(j, 'retailerId'),
        retailerCode = reportText(j, 'retailerCode'),
        retailerName = reportText(j, 'retailerName'),
        recognitionDate = reportText(j, 'recognitionDate'),
        revenueBeforePromotion = reportNumber(j, 'revenueBeforePromotion'),
        promotionAmount = reportNumber(j, 'promotionAmount'),
        revenueAfterPromotion = reportNumber(j, 'revenueAfterPromotion'),
        adjustment = reportNumber(j, 'approvedAdjustmentAmount'),
        recognizedRevenue = reportNumber(j, 'recognizedRevenue');
  final String id,
      code,
      retailerId,
      retailerCode,
      retailerName,
      recognitionDate;
  final num revenueBeforePromotion, promotionAmount, revenueAfterPromotion;
  final num adjustment, recognizedRevenue;
}

class SalesKpiEntry {
  SalesKpiEntry.fromJson(Map<String, dynamic> j)
      : salesUserId = reportText(j, 'salesUserId'),
        salesGroupId = reportText(j, 'salesGroupId'),
        groupName = reportText(j, 'salesGroupName'),
        overallCompletionRate = reportNumber(j, 'overallCompletionRate'),
        recognizedRevenue = reportNumber(j, 'recognizedRevenue'),
        metrics = reportRows(j, 'metrics', KpiMetric.fromJson),
        orders = reportRows(j, 'orders', KpiOrder.fromJson);
  final String salesUserId, salesGroupId, groupName;
  final num overallCompletionRate, recognizedRevenue;
  final List<KpiMetric> metrics;
  final List<KpiOrder> orders;
}

class SalesKpi extends PerformanceReport<SalesKpiEntry> {
  SalesKpi.fromJson(Map<String, dynamic> j, DateTime loadedAt)
      : configurationVersion = reportNumber(j, 'configurationVersion').toInt(),
        configurationEffectiveFrom =
            reportText(j, 'configurationEffectiveFrom'),
        recognitionRule = reportText(j, 'recognitionRule'),
        super.fromJson(j, SalesKpiEntry.fromJson, loadedAt);
  final int configurationVersion;
  final String configurationEffectiveFrom, recognitionRule;
}

class RankingEntry {
  RankingEntry.fromJson(Map<String, dynamic> j)
      : rank = reportNumber(j, 'rank').toInt(),
        salesUserId = reportText(j, 'salesUserId'),
        salesGroupId = reportText(j, 'salesGroupId'),
        name = reportText(j, 'salesUserName'),
        group = reportText(j, 'salesGroupName'),
        orderCount = reportNumber(j, 'orderCount').toInt(),
        recognizedRevenue = reportNumber(j, 'recognizedRevenue');
  final int rank, orderCount;
  final String salesUserId, salesGroupId, name, group;
  final num recognizedRevenue;
}

class ProductRanking {
  ProductRanking.fromJson(Map<String, dynamic> j)
      : rank = reportNumber(j, 'rank').toInt(),
        sku = reportText(j, 'sku'),
        name = reportText(j, 'productName'),
        quantity = reportNumber(j, 'normalizedSoldQuantity'),
        unit = reportText(j, 'quantityUnit'),
        adjustedNetRevenue = reportNumber(j, 'adjustedNetRevenue');
  final int rank;
  final String sku, name, unit;
  final num quantity, adjustedNetRevenue;
}
