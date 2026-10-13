import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/performance.dart';

final performanceApiProvider = Provider<PerformanceApi>(
    (ref) => PerformanceApi(ref.watch(apiClientProvider)));

/// `/kpi/sales`, `/rankings/sales`, `/rankings/products`.
class PerformanceApi {
  PerformanceApi(this._client);

  final ApiClient _client;

  Future<SalesKpi> kpi({String period = 'month'}) async {
    final data = await _client.get(
      Endpoints.kpiSales,
      query: <String, dynamic>{'period': period},
    );
    return SalesKpi.fromJson(asMap(data));
  }

  Future<List<RankingEntry>> salesRanking({String period = 'month'}) async {
    final data = await _client.get(
      Endpoints.rankingsSales,
      query: <String, dynamic>{'period': period},
    );
    return unwrapItems(data).map(RankingEntry.fromJson).toList();
  }

  Future<List<ProductRanking>> productRanking({String period = 'month'}) async {
    final data = await _client.get(
      Endpoints.rankingsProducts,
      query: <String, dynamic>{'period': period},
    );
    return unwrapItems(data).map(ProductRanking.fromJson).toList();
  }
}
