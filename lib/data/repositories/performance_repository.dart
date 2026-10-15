import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/remote/performance_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>(
    (ref) => PerformanceRepository(ref.watch(performanceApiProvider)));

final salesKpiProvider =
    FutureProvider.autoDispose.family<SalesKpi, String>((ref, period) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(performanceRepositoryProvider).kpi(period);
});

final salesRankingProvider = FutureProvider.autoDispose
    .family<List<RankingEntry>, String>((ref, period) {
  ref.watch(currentUserProvider);
  return ref.watch(performanceRepositoryProvider).salesRanking(period);
});

final productRankingProvider = FutureProvider.autoDispose
    .family<List<ProductRanking>, String>((ref, period) {
  ref.watch(currentUserProvider);
  return ref.watch(performanceRepositoryProvider).productRanking(period);
});

class PerformanceRepository {
  PerformanceRepository(this._api);

  final PerformanceApi _api;

  Future<SalesKpi> kpi(String period) => _api.kpi(period: period);

  Future<List<RankingEntry>> salesRanking(String period) =>
      _api.salesRanking(period: period);

  Future<List<ProductRanking>> productRanking(String period) =>
      _api.productRanking(period: period);
}
