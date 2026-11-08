import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';
import 'package:fscm_mobile/shared/widgets/warehouse_stock_list.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';

void main() {
  test(
      'reads separate warehouse quantities and reasons without subtracting stock',
      () async {
    final api = OrdersApi(ApiClient(
        transport: _AvailabilityTransport(), tokenReader: () => null));
    final result =
        await api.availabilityByWarehouse('retailer-1', ['product-1']);
    final product = result['SKU001']!;
    expect(
        product.warehouses.map((w) => w.code), ['WH-TD', 'WH-Q7', 'WH-HCM-01']);
    expect(product.warehouses.map((w) => w.quantity), [10, 30, 0]);
    expect(product.quantity, 40);
    expect(product.warehouses.last.reasonLabel, 'Ngoài phạm vi phục vụ');
    expect(OrderLimits.maxQty(10), 10);
    expect((await api.availability('retailer-1', ['product-1']))['SKU001'], 40);
  });

  testWidgets(
      'shows each warehouse separately and allows selecting the remaining ten cartons',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    final data = ProductAvailability.fromJson(_AvailabilityTransport.item);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        WarehouseStockList(warehouses: data.warehouses),
        QuantityStepper(
            value: 0,
            step: OrderLimits.step,
            max: OrderLimits.maxQty(10),
            onChanged: (v) => selected = v),
      ]),
    ))));
    expect(find.text('Kho Thủ Đức · WH-TD'), findsOneWidget);
    expect(find.text('Kho Quận 7 · WH-Q7'), findsOneWidget);
    expect(find.text('10 thùng'), findsOneWidget);
    expect(find.text('30 thùng'), findsOneWidget);
    expect(find.text('40 thùng'), findsNothing);
    expect(find.text('Ngoài phạm vi phục vụ'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    expect(selected, 10);
    expect(tester.takeException(), isNull);
  });
}

class _AvailabilityTransport implements ApiTransport {
  static const item = <String, dynamic>{
    'sku': 'SKU001',
    'eligibleQuantity': 40,
    'warehouses': [
      {
        'warehouseId': 'td',
        'warehouseCode': 'WH-TD',
        'warehouseName': 'Kho Thủ Đức',
        'eligibleQuantity': 10,
        'distanceMeters': 6016.2
      },
      {
        'warehouseId': 'q7',
        'warehouseCode': 'WH-Q7',
        'warehouseName': 'Kho Quận 7',
        'eligibleQuantity': 30,
        'distanceMeters': 8352.6
      },
      {
        'warehouseId': 'cc',
        'warehouseCode': 'WH-HCM-01',
        'warehouseName': 'Kho Củ Chi',
        'eligibleQuantity': 0,
        'distanceMeters': 33367,
        'unavailableReason': 'OutsideServiceRadius'
      },
    ],
  };
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, data: {
        'items': [item]
      });
}
