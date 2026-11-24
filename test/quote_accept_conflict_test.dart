import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';

/// M-23: Retailer quote acceptance. The request matches the Backend contract
/// (`POST /quotes/{id}/accept {expectedVersion, paymentMethod}`); every 409
/// reason of `QuoteService.AcceptAsync` is shown as its own Vietnamese,
/// actionable text; a 409 is never retried or treated as accepted.
class _Transport implements ApiTransport {
  _Transport(this.reply);
  final ApiResponse Function(ApiRequest) reply;
  final List<ApiRequest> requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return reply(request);
  }
}

SalesOrderQuote _quote({int version = 3, String status = 'Issued'}) =>
    SalesOrderQuote.fromJson(<String, dynamic>{
      'id': 'q-1',
      'salesOrderId': 'o-1',
      'status': status,
      'version': version,
      'revisionNumber': 2,
      'totalAmount': 1500000,
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 5))
          .toUtc()
          .toIso8601String(),
    });

QuotesApi _api(_Transport t) =>
    QuotesApi(ApiClient(transport: t, tokenReader: () => 'token'));

ApiResponse _conflict(String detail) =>
    ApiResponse(statusCode: 409, data: <String, dynamic>{
      'title': 'Conflict',
      'status': 409,
      'detail': detail
    });

void main() {
  test('accept sends the contract payload once and returns the accepted quote',
      () async {
    final t = _Transport(
        (r) => const ApiResponse(statusCode: 200, data: <String, dynamic>{
              'id': 'q-1',
              'salesOrderId': 'o-1',
              'status': 'Accepted',
              'version': 4,
              'revisionNumber': 2,
              'totalAmount': 1500000,
              'expiresAt': '2030-01-01T00:00:00Z',
            }));
    final accepted = await _api(t).accept(_quote(), PaymentMethod.prepaid);

    expect(accepted.status, 'Accepted');
    expect(t.requests, hasLength(1));
    expect(t.requests.single.method, 'POST');
    expect(t.requests.single.path, '/quotes/q-1/accept');
    expect(t.requests.single.body,
        <String, dynamic>{'expectedVersion': 3, 'paymentMethod': 'Prepaid'});
  });

  group('each Backend 409 reason is explained and not retried', () {
    const reasons = <String, String>{
      'Quote changed; reload before deciding.': 'tải lại đơn',
      'Only a pending quote can be decided.': 'không còn ở trạng thái chờ',
      'Order is no longer awaiting a quote decision.':
          'không còn chờ quyết định',
      'Quote acceptance deadline has passed.': 'quá hạn xác nhận',
      'Retailer has an overdue credit receivable and must settle it before using credit again.':
          'công nợ quá hạn',
      'Credit limit would be exceeded by this order. Please use prepaid payment or settle outstanding receivables.':
          'vượt hạn mức công nợ',
      'Retailer must be active to use credit.': 'chưa hoạt động',
      'Retailer does not have an approved credit term.': 'kỳ hạn hoặc hạn mức',
      'Retailer does not have an available approved credit limit.':
          'kỳ hạn hoặc hạn mức',
    };
    reasons.forEach((detail, expected) {
      test(detail, () async {
        final t = _Transport((r) => _conflict(detail));
        final method = detail.contains('credit') || detail.contains('Credit')
            ? PaymentMethod.credit
            : PaymentMethod.prepaid;
        Object? caught;
        try {
          await _api(t).accept(_quote(), method);
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<ApiException>());
        final e = caught! as ApiException;
        expect(e.kind, ApiErrorKind.conflict);
        expect(e.statusCode, 409);
        expect(e.message, contains(expected));
        // Vietnamese only; the server text is kept for diagnostics.
        expect(e.message, matches(RegExp(r'[^\x00-\x7F]')));
        expect(e.details, detail);
        // No automatic retry, no second request.
        expect(t.requests, hasLength(1));
      });
    });
  });

  test('a stale or ineligible quote is stopped before any request', () async {
    final t = _Transport((r) => throw StateError('must not be called'));
    for (final quote in [
      _quote(status: 'Accepted'),
      _quote(status: 'Expired'),
      _quote(version: 0),
    ]) {
      await expectLater(
          _api(t).accept(quote, PaymentMethod.prepaid),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.conflict)));
    }
    expect(t.requests, isEmpty);
  });

  test('only Prepaid or Credit is sent (no COD)', () async {
    final t = _Transport((r) => throw StateError('must not be called'));
    await expectLater(_api(t).accept(_quote(), PaymentMethod.unselected),
        throwsA(isA<ApiException>()));
    expect(t.requests, isEmpty);
  });
}
