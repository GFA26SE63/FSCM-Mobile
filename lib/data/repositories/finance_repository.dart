import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';
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
  final retailer = ref.watch(currentUserProvider)?.role.isRetailer ?? false;
  return ref.watch(financeRepositoryProvider).receivables(retailer: retailer);
});

class FinanceRepository {
  FinanceRepository(this._api);

  final ReceivablesApi _api;

  Future<List<Receivable>> receivables(
          {required bool retailer, String? status}) =>
      _api.list(retailer: retailer, status: status);

  Future<Receivable> collect(Receivable receivable) => _api.collect(receivable);

  Future<DebtCheckout> createDebtCheckout({
    required bool payAll,
    required List<String> paymentIds,
    required String operationKey,
  }) =>
      _api.createDebtCheckout(
          payAll: payAll, paymentIds: paymentIds, operationKey: operationKey);

  Future<DebtCheckout> debtCheckout(String checkoutId) =>
      _api.debtCheckout(checkoutId);
}
