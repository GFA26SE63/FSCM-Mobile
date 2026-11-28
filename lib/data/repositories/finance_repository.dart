import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/refund.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';
import 'package:fscm_mobile/data/remote/complaints_api.dart';
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

/// Retailer: own refund records. There is no retailer refund list on the
/// server (`/refunds` needs the Web `refunds` screen), so this reads the
/// receivable views the retailer may see: every Credit order, plus the
/// orders of own claims that raised a refund (Prepaid orders are not in the
/// receivable list).
// shortcut: a Prepaid refund not raised from a claim is not shown; needs a
// retailer refund list on the Backend.
final retailerRefundsProvider =
    FutureProvider.autoDispose<List<RetailerRefund>>((ref) async {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  final api = ref.watch(receivablesApiProvider);
  final credit = await api.retailerCreditRefunds();
  List<Complaint> claims;
  try {
    claims = await ref.watch(complaintsApiProvider).list();
  } on ApiException catch (e) {
    // Without the claims screen only the Credit refunds can be listed.
    if (e.kind != ApiErrorKind.forbidden) rethrow;
    claims = const <Complaint>[];
  }
  final loaded = credit.map((r) => r.orderId).toSet();
  final orderIds = <String>{
    for (final c in claims)
      if (c.refundId.isNotEmpty &&
          c.salesOrderId.isNotEmpty &&
          !loaded.contains(c.salesOrderId))
        c.salesOrderId,
  };
  final others = await Future.wait(orderIds.map(api.retailerOrderRefunds));
  return mergeRetailerRefunds(<RetailerRefund>[
    ...credit,
    for (final list in others) ...list,
  ]);
});

class FinanceRepository {
  FinanceRepository(this._api);

  final ReceivablesApi _api;

  Future<List<Receivable>> receivables(
          {required bool retailer, String? status}) =>
      _api.list(retailer: retailer, status: status);

  Future<DebtCheckout> createDebtCheckout({
    required bool payAll,
    required List<String> paymentIds,
    required String operationKey,
  }) =>
      _api.createDebtCheckout(
          payAll: payAll, paymentIds: paymentIds, operationKey: operationKey);

  Future<DebtCheckout> debtCheckout(String checkoutId) =>
      _api.debtCheckout(checkoutId);

  Future<List<DebtCheckout>> pendingDebtCheckouts() =>
      _api.pendingDebtCheckouts();

  Future<DebtCheckout> cancelDebtCheckout(String checkoutId) =>
      _api.cancelDebtCheckout(checkoutId);
}
