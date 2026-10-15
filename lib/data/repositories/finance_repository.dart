import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/remote/receivables_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
    (ref) => FinanceRepository(ref.watch(receivablesApiProvider)));

/// Receivables visible to the signed-in user (Sales: own retailers,
/// Retailer: own debts).
final receivablesProvider = FutureProvider.autoDispose<List<Receivable>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(financeRepositoryProvider).receivables();
});

class FinanceRepository {
  FinanceRepository(this._api);

  final ReceivablesApi _api;

  Future<List<Receivable>> receivables({String? status}) =>
      _api.list(status: status);

  Future<Receivable> collect(String orderCode) => _api.collect(orderCode);
}
