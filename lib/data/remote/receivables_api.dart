import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';

final receivablesApiProvider = Provider<ReceivablesApi>(
    (ref) => ReceivablesApi(ref.watch(apiClientProvider)));

class ReceivablesApi {
  ReceivablesApi(this._client);

  final ApiClient _client;

  /// Sales: receivables of retailers they look after. Retailer: own debts.
  Future<List<Receivable>> list(
      {required bool retailer, String? status}) async {
    final query = retailer
        ? r'''
          query RetailerReceivables($filter: RetailerReceivableFilterInput!) {
            retailerReceivables(filter: $filter) {
              items {
                id orderId orderCode paymentMethod status
                adjustedAmount confirmedCollectedAmount outstandingAmount
                pendingDisputedAmount collectibleAmount dueDate isOverdue
                daysOverdue updatedAt
              }
            }
          }
        '''
        : r'''
          query SalesReceivables($status: String) {
            receivables(status: $status) {
              id orderId orderCode retailerCode retailerName status
              adjustedAmount confirmedAmount outstandingAmount dueDate
              creditTermDays deliveredDate paidDate version
            }
          }
        ''';
    final response = asMap(await _client.post(
      Env.effectiveGraphQlEndpoint,
      body: <String, dynamic>{
        'query': query,
        'variables': retailer
            ? <String, dynamic>{
                'filter': <String, dynamic>{
                  'status': status,
                  'page': 1,
                  'pageSize': 100
                }
              }
            : <String, dynamic>{'status': status},
      },
    ));
    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw StateError('Không thể tải công nợ từ GraphQL.');
    }
    final data = asMap(response['data']);
    final items = retailer
        ? asMapList(asMap(data['retailerReceivables'])['items'])
        : asMapList(data['receivables']);
    return items.map(Receivable.fromJson).toList();
  }

  Future<DebtCheckout> createDebtCheckout({
    required bool payAll,
    required List<String> paymentIds,
    required String operationKey,
  }) async {
    final data = await _client.post(
      Endpoints.retailerDebtPayOsCheckouts,
      body: <String, dynamic>{
        'mode': payAll ? 'All' : 'Selected',
        'paymentIds': payAll ? <String>[] : paymentIds,
      },
      headers: <String, String>{'Idempotency-Key': operationKey},
    );
    return DebtCheckout.fromJson(asMap(data));
  }

  Future<DebtCheckout> debtCheckout(String checkoutId) async {
    final data =
        await _client.get(Endpoints.retailerDebtPayOsCheckout(checkoutId));
    return DebtCheckout.fromJson(asMap(data));
  }

  /// Single full collection (no partial payments, SPEC section 4).
  Future<Receivable> collect(Receivable receivable) async {
    if (receivable.isPaid) return receivable;
    final data = await _client.post(
      Endpoints.receivableCollect(receivable.orderId),
      body: <String, dynamic>{
        'collectionMethod': 'Cash',
        'expectedVersion': receivable.version,
        'note': 'Sales confirmed full cash collection on mobile.',
      },
      headers: <String, String>{
        // Reuse the operation after a lost response for this payment version.
        'Idempotency-Key': 'cash:${receivable.orderId}:${receivable.version}'
      },
    );
    return Receivable.fromJson(asMap(data));
  }
}
