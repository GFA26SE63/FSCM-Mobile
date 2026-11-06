import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_order_detail_screen.dart';

void main() {
  testWidgets('reopened prepaid order retains checkout and reports gateway failure',
      (tester) async {
    final transport = _UnavailableCheckout();
    final order = Order.fromJson({
      'id': 'order-1', 'orderCode': 'DH-001057', 'status': 'PaymentPending',
      'payment': {'method': 'Prepaid', 'status': 'Unpaid'},
      'subtotalAmount': 11440000, 'discountAmount': 635040,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        orderDetailProvider('order-1').overrideWith((ref) async => order),
        quotesApiProvider.overrideWithValue(QuotesApi(
          ApiClient(transport: transport, tokenReader: () => null),
        )),
      ],
      child: const MaterialApp(home: RtOrderDetailScreen(code: 'order-1')),
    ));
    await tester.pumpAndSettle();
    final checkout = find.text('Thanh toán qua PayOS');
    expect(checkout, findsOneWidget);
    await tester.tap(checkout);
    await tester.pumpAndSettle();
    expect(find.textContaining('Kênh PayOS hiện chưa sẵn sàng'), findsOneWidget);
    expect(checkout, findsOneWidget);
    expect(transport.requests.map((request) => request.toString()), [
      'GET /payments/orders/order-1',
      'POST /payments/orders/order-1/payos-checkout',
    ]);
  });
}

class _UnavailableCheckout implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.method == 'GET') {
      return const ApiResponse(statusCode: 200, data: {'version': 2});
    }
    return const ApiResponse(statusCode: 502, data: {
      'code': 'payment_gateway_error',
      'title': 'Gateway configuration is missing.',
    });
  }
}
