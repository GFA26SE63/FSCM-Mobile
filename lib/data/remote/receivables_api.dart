import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/refund.dart';
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

    return (await _retailerPages(_retailerQuery, 'RetailerReceivables', status))
        .map(Receivable.fromJson)
        .toList();
  }

  // Offset pages until totalCount is reached; ids dedupe overlapping pages.
  Future<List<Map<String, dynamic>>> _retailerPages(
      String query, String operationName, String? status) async {
    final rows = <String, Map<String, dynamic>>{};
    for (var page = 1; page <= _maxPages; page++) {
      final data = await _graphQl.query(query,
          operationName: operationName,
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
        return rows.values.toList();
      }
    }
    throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'Danh sách công nợ quá dài, không thể tải đầy đủ.');
  }

  static const String _refundFields = '''
    orderId orderCode paymentMethod
    refunds {
      id amount status transferredAt transactionReference verifiedAt reason
    }''';

  static const String _retailerRefundsQuery = '''
    query RetailerRefunds(\$status: String, \$page: Int!, \$pageSize: Int!) {
      retailerReceivables(
          filter: { status: \$status, page: \$page, pageSize: \$pageSize }) {
        items { id $_refundFields }
        page pageSize totalCount totalPages
      }
    }
  ''';

  static const String _orderRefundsQuery = '''
    query RetailerOrderRefunds(\$orderId: UUID!) {
      retailerReceivable(orderId: \$orderId) { $_refundFields }
    }
  ''';

  /// Retailer: refund records on own Credit orders (the receivable list
  /// holds Credit payments only).
  Future<List<RetailerRefund>> retailerCreditRefunds() async => _refunds(
      await _retailerPages(_retailerRefundsQuery, 'RetailerRefunds', null));

  /// Retailer: refund records of one own order of any payment method.
  Future<List<RetailerRefund>> retailerOrderRefunds(String orderId) async {
    final data = await _graphQl.query(_orderRefundsQuery,
        operationName: 'RetailerOrderRefunds',
        variables: <String, dynamic>{'orderId': orderId});
    return _refunds(<Map<String, dynamic>>[asMap(data['retailerReceivable'])]);
  }

  static List<RetailerRefund> _refunds(List<Map<String, dynamic>> orders) =>
      <RetailerRefund>[
        for (final order in orders)
          for (final refund in asMapList(order['refunds']))
            RetailerRefund.fromJson(refund, order),
      ];

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
}
