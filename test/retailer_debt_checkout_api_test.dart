import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/remote/receivables_api.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/features/retailer/payments/payments_screen.dart';

void main() {
  test('receivables use typed GraphQL read model', () async {
    final transport = _FinanceTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    addTearDown(client.dispose);

    final rows = await ReceivablesApi(client).list(retailer: true);

    expect(rows.single.paymentId, 'payment-1');
    expect(rows.single.collectibleAmount, 750000);
    final request = transport.requests.single;
    expect(request.path, 'http://10.0.2.2:5080/graphql');
    expect((request.body as Map)['query'], contains('retailerReceivables'));
  });

  test('GraphQL URL is outside the REST version prefix', () {
    expect(
      Endpoints.graphQlForRestBase('https://localhost:7027/api/v1'),
      'https://localhost:7027/graphql',
    );
    expect(
      Endpoints.graphQlForRestBase('https://example.test/fscm/api/v1/'),
      'https://example.test/fscm/graphql',
    );
  });

  test(
      'selected debt checkout sends only identities and preserves idempotency key',
      () async {
    final transport = _FinanceTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'token');
    addTearDown(client.dispose);

    final checkout = await ReceivablesApi(client).createDebtCheckout(
      payAll: false,
      paymentIds: const <String>['payment-1', 'payment-2'],
      operationKey: 'operation-1',
    );

    expect(checkout.amount, 1250000);
    final request = transport.requests.single;
    expect(request.path, '/retailer/receivables/payos-checkouts');
    expect(request.headers['Idempotency-Key'], 'operation-1');
    expect(request.body, <String, dynamic>{
      'mode': 'Selected',
      'paymentIds': <String>['payment-1', 'payment-2'],
    });
    expect((request.body as Map).containsKey('amount'), isFalse);
  });

  testWidgets('debt screen exposes selected and full PayOS actions',
      (tester) async {
    final receivable = Receivable.fromJson(<String, dynamic>{
      'id': 'payment-1',
      'orderId': 'order-1',
      'orderCode': 'DH-000001',
      'status': 'Unpaid',
      'adjustedAmount': 1000000,
      'outstandingAmount': 1000000,
      'collectibleAmount': 1000000,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        receivablesProvider
            .overrideWith((ref) async => <Receivable>[receivable]),
      ],
      child: const MaterialApp(home: PaymentsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Thanh toán một phần'), findsOneWidget);
    expect(find.text('Thanh toán hết'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final partial = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Thanh toán một phần'));
    expect(partial.onPressed, isNotNull);
  });
}

class _FinanceTransport implements ApiTransport {
  final List<ApiRequest> requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.path == 'http://10.0.2.2:5080/graphql') {
      return const ApiResponse(statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{
          'retailerReceivables': <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'payment-1',
                'orderId': 'order-1',
                'orderCode': 'DH-000001',
                'status': 'PartiallyPaid',
                'adjustedAmount': 1000000,
                'outstandingAmount': 800000,
                'collectibleAmount': 750000,
              },
            ],
          },
        },
      });
    }
    return const ApiResponse(statusCode: 200, data: <String, dynamic>{
      'id': 'checkout-1',
      'status': 'Pending',
      'amount': 1250000,
      'checkoutUrl': 'https://pay.payos.vn/checkout-1',
      'allocations': <Map<String, dynamic>>[],
    });
  }
}
