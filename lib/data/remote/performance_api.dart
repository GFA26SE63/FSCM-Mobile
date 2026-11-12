import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/performance.dart';

final performanceApiProvider = Provider<PerformanceApi>(
    (ref) => PerformanceApi(ref.watch(apiClientProvider)));

class PerformanceApi {
  PerformanceApi(this._client);
  final ApiClient _client;

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
      await _read(Endpoints.kpiSales, period), AppClock.now());

  Future<PerformanceReport<RankingEntry>> salesRanking(
          PerformancePeriod period) async =>
      PerformanceReport.fromJson(await _read(Endpoints.rankingsSales, period),
          RankingEntry.fromJson, AppClock.now());

  Future<PerformanceReport<ProductRanking>> productRanking(
      PerformancePeriod period, String criterion) async {
    if (criterion != 'Quantity' && criterion != 'Revenue') {
      throw ArgumentError.value(criterion, 'criterion');
    }
    final data =
        await _read(Endpoints.rankingsProducts, period, criterion: criterion);
    if (data['criterion'] != criterion) {
      invalidPerformanceResponse();
    }
    return PerformanceReport.fromJson(
        data, ProductRanking.fromJson, AppClock.now());
  }
}
