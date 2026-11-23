import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/payment_result.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final quotesApiProvider =
    Provider<QuotesApi>((ref) => QuotesApi(ref.watch(apiClientProvider)));

final orderQuotesProvider = FutureProvider.autoDispose
    .family<List<SalesOrderQuote>, String>((ref, orderId) {
  ref.watch(currentUserProvider);
  ref.watch(dataVersionProvider);
  if (orderId.isEmpty) return Future.value(const <SalesOrderQuote>[]);
  return ref.watch(quotesApiProvider).forOrder(orderId);
});

class QuotesApi {
  QuotesApi(this._client);

  final ApiClient _client;

  Future<List<SalesOrderQuote>> forOrder(String orderId) async {
    final data = await _client.get(Endpoints.quotesForOrder(orderId));
    return asMapList(data).map(SalesOrderQuote.fromJson).toList();
  }

  Future<SalesOrderQuote> accept(
      SalesOrderQuote quote, PaymentMethod paymentMethod) async {
    _requireDecidable(quote);
    if (paymentMethod != PaymentMethod.prepaid &&
        paymentMethod != PaymentMethod.credit) {
      throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Chỉ hỗ trợ trả trước hoặc công nợ. Không áp dụng COD.');
    }
    try {
      final data = await _client.post(
        Endpoints.quoteAccept(quote.id),
        body: <String, dynamic>{
          'expectedVersion': quote.version,
          'paymentMethod': paymentMethod.code,
        },
      );
      return SalesOrderQuote.fromJson(asMap(data));
    } on ApiException catch (error) {
      _debugLogAcceptFailure(quote, paymentMethod, error);
      rethrow; // unchanged behaviour: no retry, same error to the caller
    }
  }

  /// TEMPORARY, debug builds only (M-23.1): shows the server's real answer to a
  /// rejected acceptance. Logs ids, status codes, the ProblemDetails body and
  /// quote state only; never headers, tokens, user data or card details.
  void _debugLogAcceptFailure(
      SalesOrderQuote quote, PaymentMethod method, ApiException error) {
    if (!kDebugMode) return;
    final body = error.problemDetails;
    debugPrint('[QUOTE-ACCEPT-DIAG] POST ${Endpoints.quoteAccept(quote.id)} '
        '-> HTTP ${error.statusCode} kind=${error.kind.name}');
    debugPrint('[QUOTE-ACCEPT-DIAG] code=${error.code} title=${error.title} '
        'detail=${body?['detail'] ?? error.details ?? error.message}');
    debugPrint('[QUOTE-ACCEPT-DIAG] errors=${error.errors} '
        'problemDetails=${body == null ? 'null' : jsonEncode(body)}');
    debugPrint('[QUOTE-ACCEPT-DIAG] quote status=${quote.status} '
        'expectedVersion=${quote.version} revision=${quote.revisionNumber} '
        'expiresAt=${quote.expiresAt.toUtc().toIso8601String()} '
        'now=${DateTime.now().toUtc().toIso8601String()} '
        'paymentMethod=${method.code}');
  }

  Future<SalesOrderQuote> reject(SalesOrderQuote quote, String reason) async {
    _requireDecidable(quote);
    if (reason.trim().isEmpty) {
      throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Vui lòng nhập lý do từ chối báo giá.');
    }
    final data = await _client.post(
      Endpoints.quoteReject(quote.id),
      body: <String, dynamic>{
        'expectedVersion': quote.version,
        'reason': reason.trim(),
      },
    );
    return SalesOrderQuote.fromJson(asMap(data));
  }

  void _requireDecidable(SalesOrderQuote quote) {
    if (!quote.canDecide) {
      throw const ApiException(
          kind: ApiErrorKind.conflict,
          message:
              'Báo giá đã hết hạn hoặc không còn chờ xác nhận. Hãy tải lại.');
    }
  }

  Future<PayOsCheckout> createPayOsCheckout(String orderId) async {
    final paymentData = await paymentForOrder(orderId);
    final data = await _client.post(
      Endpoints.payOsCheckout(orderId),
      body: <String, dynamic>{'expectedVersion': paymentData.version},
    );
    return PayOsCheckout.fromJson(asMap(data));
  }

  Future<PaymentResult> paymentForOrder(String orderId) async =>
      PaymentResult.fromJson(
          asMap(await _client.get(Endpoints.paymentForOrder(orderId))));
}
