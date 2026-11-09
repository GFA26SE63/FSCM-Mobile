import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_order_detail_screen.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';

void main() {
  testWidgets(
      'order detail shows business code, promotion name and batch expiry',
      (tester) async {
    const promotionId = '740f093b-003b-4b94-b667-981de8226262';
    final order = Order.fromJson({
      'id': 'order-2',
      'orderCode': 'DH-001057',
      'status': 'Picking',
      'paymentMethod': 'Credit',
      'lines': [
        {
          'sku': 'SKU001',
          'productName': 'Sữa tươi',
          'quantity': 20,
          'unitPrice': 252000,
          'discountAmount': 403200,
          'discountSourceCode': promotionId,
          'ordinaryPromotion': {'name': 'Ưu đãi số lượng'},
          'allocations': [
            {'batchCode': 'BATCH-1', 'quantity': 20}
          ],
          'allocationFragments': [
            {
              'batchCode': 'BATCH-1',
              'quantity': 20,
              'batchExpirationDate': '2026-11-16'
            },
          ],
        },
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        orderDetailProvider('order-2').overrideWith((ref) async => order),
      ],
      child: const MaterialApp(home: RtOrderDetailScreen(code: 'order-2')),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'DH-001057'), findsOneWidget);
    expect(find.textContaining('16/11/2026'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OrderLinesCard),
        matching: find.text('Ưu đãi số lượng'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppliedPromoCard),
        matching: find.text('Ưu đãi số lượng'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining(promotionId), findsNothing);
  });

  testWidgets(
      'reopened prepaid order retains checkout and reports gateway failure',
      (tester) async {
    final transport = _UnavailableCheckout();
    final order = Order.fromJson({
      'id': 'order-1',
      'orderCode': 'DH-001057',
      'status': 'PaymentPending',
      'payment': {'method': 'Prepaid', 'status': 'Unpaid'},
      'subtotalAmount': 11440000,
      'discountAmount': 635040,
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
    expect(
        find.textContaining('Kênh PayOS hiện chưa sẵn sàng'), findsOneWidget);
    expect(checkout, findsOneWidget);
    await tester.ensureVisible(find.text('Đổi sang công nợ'));
    await tester.tap(find.text('Đổi sang công nợ'));
    await tester.pumpAndSettle();
    expect(find.text('Đổi sang công nợ?'), findsOneWidget);
    await tester.tap(find.text('Giữ trả trước'));
    await tester.pumpAndSettle();
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
