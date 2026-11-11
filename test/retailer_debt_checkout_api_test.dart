import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/data/remote/receivables_api.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/features/retailer/payments/payments_screen.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';

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

  test('GraphQL configuration is separate from the REST version prefix', () {
    expect(
      Env.graphQlEndpointFor(
        'https://localhost:7027/api/v1',
        configuredEndpoint: 'https://localhost:7027/graphql',
      ),
      'https://localhost:7027/graphql',
    );
    expect(
      Env.graphQlEndpointFor('https://example.test/fscm/api/v1/'),
      'https://example.test/fscm/graphql',
    );
  });

  test('cancelled PayOS checkout is terminal', () {
    const checkout = DebtCheckout(
      id: 'checkout-1',
      status: 'Cancelled',
      amount: 292500,
      checkoutUrl: 'https://pay.payos.vn/checkout-1',
      allocations: <DebtCheckoutAllocation>[],
    );

    expect(checkout.isTerminal, isTrue);
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

  testWidgets('payment status filters scroll horizontally on narrow screens',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: ChipFilterBar<int>(
              padding: EdgeInsets.zero,
              selected: 0,
              onSelected: (_) {},
              options: const <ChipOption<int>>[
                ChipOption(0, 'Tất cả'),
                ChipOption(1, 'Cần trả'),
                ChipOption(2, 'Quá hạn'),
                ChipOption(3, 'Đã trả'),
                ChipOption(4, 'Trả trước'),
              ],
            ),
          ),
        ),
      ),
    ));

    final scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(-180, 0));
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(
        find.descendant(of: scrollable, matching: find.byType(Scrollable)));
    expect(state.position.pixels, greaterThan(0));
    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('compact empty states do not overflow', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 140,
          child: EmptyState(
            title: 'Không có khoản công nợ phù hợp.',
            icon: Icons.verified_outlined,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('payment debts can be searched, filtered and sorted locally',
      (tester) async {
    final rows = <Receivable>[
      Receivable.fromJson(<String, dynamic>{
        'id': 'payment-1',
        'orderId': 'order-1',
        'orderCode': 'DH-LOW',
        'status': 'Unpaid',
        'adjustedAmount': 100000,
        'outstandingAmount': 100000,
        'collectibleAmount': 100000,
        'dueDate': '2030-01-01T00:00:00Z',
      }),
      Receivable.fromJson(<String, dynamic>{
        'id': 'payment-2',
        'orderId': 'order-2',
        'orderCode': 'DH-HIGH',
        'status': 'Unpaid',
        'adjustedAmount': 500000,
        'outstandingAmount': 500000,
        'collectibleAmount': 500000,
        'dueDate': '2030-02-01T00:00:00Z',
      }),
      Receivable.fromJson(<String, dynamic>{
        'id': 'payment-3',
        'orderId': 'order-3',
        'orderCode': 'DH-PAID',
        'status': 'Paid',
        'adjustedAmount': 200000,
        'confirmedAmount': 200000,
      }),
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [receivablesProvider.overrideWith((ref) async => rows)],
      child: const MaterialApp(home: PaymentsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DH-HIGH'), findsOneWidget);
    expect(tester.getTopLeft(find.text('DH-LOW')).dy,
        lessThan(tester.getTopLeft(find.text('DH-HIGH')).dy));

    await tester.enterText(find.byType(TextField), 'PAID');
    await tester.pump();
    expect(find.text('DH-PAID'), findsOneWidget);
    expect(find.text('DH-HIGH'), findsNothing);

    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pump();
    await tester.tap(find.text('Đã trả'));
    await tester.pumpAndSettle();
    expect(find.text('DH-PAID'), findsOneWidget);
    expect(find.text('DH-HIGH'), findsNothing);

    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byWidgetPredicate((widget) => widget is DropdownButtonFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Số tiền cao đến thấp').last);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('DH-HIGH')).dy,
        lessThan(tester.getTopLeft(find.text('DH-LOW')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'payment confirmation keeps the back action full-width below PayOS',
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

    await tester.tap(find.text('Thanh toán hết'));
    await tester.pumpAndSettle();

    final pay = find.widgetWithText(FilledButton, 'Thanh toán với PayOS');
    final back = find.widgetWithText(OutlinedButton, 'Quay lại');
    expect(tester.getSize(pay).width, tester.getSize(back).width);
    expect(tester.getTopLeft(back).dy, greaterThan(tester.getTopLeft(pay).dy));
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
