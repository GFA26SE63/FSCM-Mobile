import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/performance.dart';

final performanceApiProvider = Provider<PerformanceApi>(
    (ref) => PerformanceApi(ref.watch(apiClientProvider)));

class PerformanceApi {
  PerformanceApi(this._client) : _graphQl = GraphQlClient(_client);
  final ApiClient _client;
  final GraphQlClient _graphQl;

  // `salesKpis` and `bestSellingProducts` run the same ReportService with the
  // same actor and roles as REST /reports/sales-kpis and
  // /reports/best-selling-products (the Backend tests assert that parity).
  // Only the fields the app reads are selected. Sales ranking has no GraphQL
  // query and stays REST.
  static const String _kpiFields = '''
    fromDate toDate scope configurationVersion configurationEffectiveFrom
    recognitionRule
    entries {
      salesUserId salesGroupId salesGroupName overallCompletionRate
      recognizedRevenue
      metrics {
        code name target actual completionRate weight weightedScore unit
      }
      orders {
        orderId orderCode retailerId retailerCode retailerName
        recognitionDate revenueBeforePromotion promotionAmount
        revenueAfterPromotion approvedAdjustmentAmount recognizedRevenue
      }
    }''';

  static const String _productFields = '''
    fromDate toDate criterion scope
    entries {
      rank sku productName normalizedSoldQuantity quantityUnit
      adjustedNetRevenue
    }''';

  static final RegExp _dateLiteral = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// The dates and criterion are inlined as literals (as the Backend tests
  /// do), so they are validated first; nothing else reaches the document.
  String _period(PerformancePeriod period) {
    if (!_dateLiteral.hasMatch(period.fromDate) ||
        !_dateLiteral.hasMatch(period.toDate)) {
      throw ArgumentError.value(period, 'period', 'Dates must be yyyy-MM-dd.');
    }
    return 'fromDate: "${period.fromDate}", toDate: "${period.toDate}"';
  }

  /// GraphQL first. A generic or schema error is re-read through REST, which
  /// answers with the precise status and message (GraphQL hides domain errors
  /// such as "period starts in the future"). Network and authentication
  /// failures are not retried.
  Future<Map<String, dynamic>> _readGraphQl(
    String field,
    String document,
    String operation,
    Future<Map<String, dynamic>> Function() rest,
    PerformancePeriod period,
  ) async {
    Map<String, dynamic>? result;
    try {
      final data = await _graphQl.query(document, operationName: operation);
      final value = data[field];
      if (value is Map<String, dynamic>) result = value;
    } on ApiException catch (error) {
      if (error.isNetwork ||
          error.kind == ApiErrorKind.unauthorized ||
          error.kind == ApiErrorKind.forbidden) {
        rethrow;
      }
      return rest();
    }
    // A malformed answer is an error of its own, not a reason to fall back.
    if (result == null) invalidPerformanceResponse();
    _checkPeriod(result, period);
    return result;
  }

  void _checkPeriod(Map<String, dynamic> data, PerformancePeriod period) {
    if (data['fromDate'] != period.fromDate ||
        data['toDate'] != period.toDate) {
      invalidPerformanceResponse();
    }
  }

  Future<Map<String, dynamic>> _read(String endpoint, PerformancePeriod period,
      {String? criterion}) async {
    final data = await _client.get(endpoint, query: {
      ...period.query,
      if (criterion != null) 'criterion': criterion,
    });
    if (data is! Map<String, dynamic>) {
      invalidPerformanceResponse();
    }
    if (data['fromDate'] != period.fromDate ||
        data['toDate'] != period.toDate) {
      invalidPerformanceResponse();
    }
    return data;
  }

  Future<SalesKpi> kpi(PerformancePeriod period) async => SalesKpi.fromJson(
      await _readGraphQl(
        'salesKpis',
        'query SalesKpi { salesKpis(query: { ${_period(period)} }) '
            '{ $_kpiFields } }',
        'SalesKpi',
        () => _read(Endpoints.kpiSales, period),
        period,
      ),
      AppClock.now());

  Future<PerformanceReport<RankingEntry>> salesRanking(
          PerformancePeriod period) async =>
      PerformanceReport.fromJson(await _read(Endpoints.rankingsSales, period),
          RankingEntry.fromJson, AppClock.now());

  Future<PerformanceReport<ProductRanking>> productRanking(
      PerformancePeriod period, String criterion) async {
    if (criterion != 'Quantity' && criterion != 'Revenue') {
      throw ArgumentError.value(criterion, 'criterion');
    }
    final data = await _readGraphQl(
      'bestSellingProducts',
      'query BestSellingProducts { bestSellingProducts(query: '
          '{ ${_period(period)}, criterion: "$criterion" }) '
          '{ $_productFields } }',
      'BestSellingProducts',
      () => _read(Endpoints.rankingsProducts, period, criterion: criterion),
      period,
    );
    if (data['criterion'] != criterion) {
      invalidPerformanceResponse();
    }
    return PerformanceReport.fromJson(
        data, ProductRanking.fromJson, AppClock.now());
  }
}
