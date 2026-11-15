import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/remote/performance_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  return PerformanceRepository(ref.watch(performanceApiProvider),
      userId: user?.id ?? '', isSales: user?.role == UserRole.sales);
});

final salesKpiProvider =
    FutureProvider.autoDispose.family<SalesKpi, String>((ref, period) {
  ref.watch(dataVersionProvider);
  return ref.watch(performanceRepositoryProvider).kpi(period);
});

final salesRankingProvider = FutureProvider.autoDispose
    .family<PerformanceReport<RankingEntry>, String>((ref, period) {
  ref.watch(dataVersionProvider);
  return ref.watch(performanceRepositoryProvider).salesRanking(period);
});

final productRankingProvider = FutureProvider.autoDispose
    .family<PerformanceReport<ProductRanking>, (String, String)>((ref, query) {
  ref.watch(dataVersionProvider);
  return ref
      .watch(performanceRepositoryProvider)
      .productRanking(query.$1, query.$2);
});

class PerformanceRepository {
  PerformanceRepository(this._api,
      {required this.userId, required this.isSales});
  final PerformanceApi _api;
  final String userId;
  final bool isSales;

  PerformancePeriod _period(String key) {
    if (!isSales || userId.isEmpty) {
      throw const ApiException(
          kind: ApiErrorKind.forbidden,
          message: 'Chỉ Sales được xem KPI của mình trên màn hình này.');
    }
    return PerformancePeriod.forKey(key, AppClock.now());
  }

  Future<SalesKpi> kpi(String period) async {
    final result = await _api.kpi(_period(period));
    // A scope mismatch is an error, never a successful empty KPI.
    if (result.entries.any((entry) => entry.salesUserId != userId)) {
      throw const ApiException(
          kind: ApiErrorKind.forbidden,
          message: 'Dữ liệu KPI không thuộc tài khoản đang đăng nhập.');
    }
    return result;
  }

  Future<PerformanceReport<RankingEntry>> salesRanking(String period) =>
      _api.salesRanking(_period(period));

  Future<PerformanceReport<ProductRanking>> productRanking(
          String period, String criterion) =>
      _api.productRanking(_period(period), criterion);
}
