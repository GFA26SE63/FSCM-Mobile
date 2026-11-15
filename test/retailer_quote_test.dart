import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';

import 'fixtures/retailer_order_fixture.dart';

void main() {
  test(
      'only latest revision for the actual order can be presented for a decision',
      () {
    final rows = [
      retailerQuoteFixture(revision: 1),
      retailerQuoteFixture(revision: 3, status: 'Accepted'),
      retailerQuoteFixture(revision: 8, orderId: 'another-order')
    ];
    final latest = SalesOrderQuote.latestForOrder(rows, 'order-1')!;
    expect(latest.revisionNumber, 3);
    expect(latest.canDecide, isFalse);
    expect(SalesOrderQuote.latestForOrder(rows, 'unknown'), isNull);
  });

  test('deadline, missing version and invalid expiry fail closed', () {
    final at = DateTime.utc(2026, 11, 10);
    final quote = retailerQuoteFixture(expiresAt: at);
    expect(quote.canDecideAt(at.subtract(const Duration(seconds: 1))), isTrue);
    expect(quote.canDecideAt(at), isFalse);
    expect(quote.canDecideAt(at.add(const Duration(seconds: 1))), isFalse);
    expect(
        SalesOrderQuote.fromJson(
            {'id': 'q', 'salesOrderId': 'o', 'status': 'Issued'}).canDecide,
        isFalse);
  });

  test(
      'accept posts expected version and supported payment, reject trims its required reason',
      () async {
    final transport = _QuoteTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    addTearDown(client.dispose);
    final api = QuotesApi(client);
    final quote = retailerQuoteFixture();
    await api.accept(quote, PaymentMethod.prepaid);
    expect(transport.requests.single.path, '/quotes/quote-1/accept');
    expect(transport.requests.single.body,
        {'expectedVersion': 3, 'paymentMethod': 'Prepaid'});
    await api.reject(quote, '  Không phù hợp  ');
    expect(transport.requests.last.body,
        {'expectedVersion': 3, 'reason': 'Không phù hợp'});
    await expectLater(api.accept(quote, PaymentMethod.unselected),
        throwsA(isA<ApiException>()));
    await expectLater(api.reject(quote, '   '), throwsA(isA<ApiException>()));
    await expectLater(
        api.accept(retailerQuoteFixture(expiresAt: DateTime.utc(2000)),
            PaymentMethod.prepaid),
        throwsA(isA<ApiException>()));
    expect(transport.requests.length, 2);
    expect(quote.totalAmount, 1000.25);
  });

  test(
      'credit requires an approved term and quote mutation refreshes data even on conflict',
      () async {
    for (final days in [0, 5, 7, 14, 30]) {
      final transport = _QuoteTransport();
      final client =
          ApiClient(transport: transport, tokenReader: () => 'token');
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(const AppUser(
            id: 'retailer-user',
            fullName: '',
            phone: '',
            role: UserRole.retailer)),
        quotesApiProvider.overrideWithValue(QuotesApi(client)),
        retailerCreditProvider('retailer-1')
            .overrideWith((ref) async => creditRetailerFixture(days)),
      ]);
      try {
        final action = container.read(retailerOrderActionsProvider);
        if ([7, 14, 30].contains(days)) {
          await action.accept(retailerOrderFixture(), retailerQuoteFixture(),
              PaymentMethod.credit);
          expect((transport.requests.single.body as Map)['paymentMethod'],
              'Credit');
          expect(container.read(dataVersionProvider), 1);
          transport.conflict = true;
          await expectLater(
              action.reject(
                  retailerOrderFixture(), retailerQuoteFixture(), 'Từ chối'),
              throwsA(isA<ApiException>()
                  .having((error) => error.statusCode, 'status', 409)));
          expect(container.read(dataVersionProvider), 2);
        } else {
          await expectLater(
              action.accept(retailerOrderFixture(), retailerQuoteFixture(),
                  PaymentMethod.credit),
              throwsA(isA<ApiException>()));
          expect(transport.requests, isEmpty);
        }
      } finally {
        container.dispose();
        client.dispose();
      }
    }
  });

  test('another role cannot invoke retailer quote decisions', () async {
    final transport = _QuoteTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(const AppUser(
          id: 'sales-user', fullName: '', phone: '', role: UserRole.sales)),
      quotesApiProvider.overrideWithValue(QuotesApi(client)),
    ]);
    addTearDown(container.dispose);
    addTearDown(client.dispose);
    await expectLater(
        container.read(retailerOrderActionsProvider).accept(
            retailerOrderFixture(),
            retailerQuoteFixture(),
            PaymentMethod.prepaid),
        throwsA(isA<ApiException>()));
    expect(transport.requests, isEmpty);
  });
}

class _QuoteTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  bool conflict = false;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (conflict) {
      return const ApiResponse(
          statusCode: 409, data: {'title': 'Quote changed'});
    }
    return const ApiResponse(statusCode: 200, data: {
      'id': 'quote-1',
      'salesOrderId': 'order-1',
      'status': 'Accepted',
      'version': 4,
    });
  }
}
