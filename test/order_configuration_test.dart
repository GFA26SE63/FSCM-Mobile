import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/data/remote/order_configuration_api.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/shared/widgets/order_stock_summary.dart';

void main() {
  test(
      'uses active server step; only a successful missing setting defaults to one',
      () async {
    for (final step in [1, 2, 10]) {
      final client = ApiClient(
          transport: _Transport([
            {
              'key': 'order.order_step_cartons',
              'isActive': true,
              'value': step
            },
          ]),
          tokenReader: () => 'token');
      addTearDown(client.dispose);
      expect(await OrderConfigurationApi(client).orderStep(), step);
    }
    final client =
        ApiClient(transport: _Transport([]), tokenReader: () => 'token');
    addTearDown(client.dispose);
    expect(await OrderConfigurationApi(client).orderStep(), 1);
  });

  test('malformed configuration and server failure do not become step one',
      () async {
    for (final data in [
      <String, Object>{},
      [
        {'key': 'order.order_step_cartons', 'isActive': true, 'value': 0}
      ],
    ]) {
      final client =
          ApiClient(transport: _Transport(data), tokenReader: () => 'token');
      addTearDown(client.dispose);
      await expectLater(OrderConfigurationApi(client).orderStep(),
          throwsA(isA<ApiException>()));
    }
    final client = ApiClient(
        transport: _Transport({}, status: 500), tokenReader: () => 'token');
    addTearDown(client.dispose);
    await expectLater(OrderConfigurationApi(client).orderStep(),
        throwsA(isA<ApiException>()));
  });

  test('reads real availability contract without inventing warehouse stock',
      () async {
    final client = ApiClient(
        transport: _Transport({
          'checkedAt': '2026-11-10T06:00:00Z',
          'items': [
            {'productId': 'p1', 'sku': 'SKU001', 'eligibleQuantity': 6}
          ],
        }),
        tokenReader: () => 'token');
    addTearDown(client.dispose);
    final rows = await OrdersApi(client).availabilityByWarehouse('r1', ['p1']);
    expect(rows['SKU001']!.quantity, 6);
    expect(rows['SKU001']!.warehouses, isEmpty);
    expect(rows['SKU001']!.checkedAt, DateTime.utc(2026, 11, 10, 6));
  });

  testWidgets(
      'positive total without warehouse details never displays no stock',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: OrderStockSummary(
      availability:
          ProductAvailability(sku: 'SKU001', quantity: 6, warehouses: []),
    ))));
    expect(
        find.text('Đủ điều kiện giao cho điểm bán: 6 thùng'), findsOneWidget);
    expect(find.text('Không có hàng đủ điều kiện để giao.'), findsNothing);
  });

  test('incomplete availability is an error instead of zero stock', () async {
    final client = ApiClient(
        transport: _Transport({'items': []}), tokenReader: () => 'token');
    addTearDown(client.dispose);
    await expectLater(OrdersApi(client).availability('r1', ['p1']),
        throwsA(isA<ApiException>()));
  });
}

class _Transport implements ApiTransport {
  _Transport(this.data, {this.status = 200});
  final Object data;
  final int status;
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      ApiResponse(statusCode: status, data: data);
}
