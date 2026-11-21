import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';

final receivablesApiProvider = Provider<ReceivablesApi>(
    (ref) => ReceivablesApi(ref.watch(apiClientProvider)));

class ReceivablesApi {
  ReceivablesApi(this._client) : _graphQl = GraphQlClient(_client);

  final ApiClient _client;
  final GraphQlClient _graphQl;

  static const String _retailerQuery = r'''
    query RetailerReceivables($status: String, $page: Int!, $pageSize: Int!) {
      retailerReceivables(
          filter: { status: $status, page: $page, pageSize: $pageSize }) {
        items {
          id orderId orderCode paymentMethod status
          adjustedAmount confirmedCollectedAmount outstandingAmount
          pendingDisputedAmount collectibleAmount dueDate isOverdue
          daysOverdue updatedAt
        }
        page pageSize totalCount totalPages
      }
    }
  ''';

  static const String _salesQuery = r'''
    query SalesReceivables($status: String) {
      receivables(status: $status) {
        id orderId orderCode retailerCode retailerName status
        adjustedAmount confirmedAmount outstandingAmount dueDate
        creditTermDays deliveredDate paidDate version
      }
    }
  ''';

  /// Backend maximum page size (1..100), not a cap on the data returned.
  static const int _pageSize = 100;

  /// Safety stop so a misbehaving server cannot loop us forever; reaching it
  /// is an error, never a silent truncation.
  static const int _maxPages = 500;

  /// Sales: receivables of retailers they look after. Retailer: own debts.
  Future<List<Receivable>> list(
      {required bool retailer, String? status}) async {
    if (!retailer) {
      final data = await _graphQl.query(_salesQuery,
          operationName: 'SalesReceivables',
          variables: <String, dynamic>{'status': status});
      return asMapList(data['receivables']).map(Receivable.fromJson).toList();
    }

    // Offset pages until totalCount is reached; ids dedupe overlapping pages.
    final rows = <String, Map<String, dynamic>>{};
    for (var page = 1; page <= _maxPages; page++) {
      final data = await _graphQl.query(_retailerQuery,
          operationName: 'RetailerReceivables',
          variables: <String, dynamic>{
            'status': status,
            'page': page,
            'pageSize': _pageSize,
          });
      final result = asMap(data['retailerReceivables']);
      final items = asMapList(result['items']);
      final before = rows.length;
      for (final item in items) {
        rows[asStr(item['id'])] = item;
      }
      final totalCount = asInt(result['totalCount']);
      final totalPages = asInt(result['totalPages']);
      if (items.isEmpty ||
          result['totalCount'] == null || // no paging metadata: one page
          rows.length == before ||
          (totalCount > 0 && rows.length >= totalCount) ||
          (totalPages > 0 && page >= totalPages)) {
        return rows.values.map(Receivable.fromJson).toList();
      }
    }
    throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'Danh sách công nợ quá dài, không thể tải đầy đủ.');
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
