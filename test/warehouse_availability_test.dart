import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/features/sales/products/product_detail_screen.dart';
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

  testWidgets('shows each warehouse separately and allows selecting one carton',
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
    expect(find.text('Ngoài phạm vi phục vụ'), findsNothing);
    expect(find.text('Kho Củ Chi · WH-HCM-01'), findsNothing);
    await tester.tap(find.byIcon(Icons.add));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'previews the three highest serviceable warehouses and opens all in product detail',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final warehouses = [
      for (final entry in {'A': 10, 'B': 50, 'C': 20, 'D': 40, 'E': 30}.entries)
        WarehouseAvailability(
            id: entry.key,
            code: 'WH-${entry.key}',
            name: 'Kho ${entry.key}',
            quantity: entry.value),
      const WarehouseAvailability(
          id: 'far',
          code: 'FAR',
          name: 'Kho quá xa',
          quantity: 0,
          unavailableReason: 'OutsideServiceRadius'),
    ];
    final availability = ProductAvailability(
        sku: 'SKU001', quantity: 150, warehouses: warehouses);
    expect(availability.serviceWarehouses.map((w) => w.code),
        ['WH-B', 'WH-D', 'WH-E', 'WH-C', 'WH-A']);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: WarehouseStockList(
                  warehouses: warehouses,
                  onViewAll: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ProductDetailScreen(
                                product: const Product(
                                    sku: 'SKU001',
                                    name: 'Sữa tươi',
                                    pack: 'Thùng',
                                    category: 'Sữa',
                                    basePrice: 1000),
                                unitPrice: 1000,
                                availability: availability,
                                promotions: const [
                                  Promotion(
                                      id: 'internal-promotion-id',
                                      name: 'Ưu đãi mùa hè',
                                      type: 1)
                                ],
                              ))),
                )))));
    expect(find.text('Kho B · WH-B'), findsOneWidget);
    expect(find.text('Kho D · WH-D'), findsOneWidget);
    expect(find.text('Kho E · WH-E'), findsOneWidget);
    expect(find.text('Kho C · WH-C'), findsNothing);
    expect(find.textContaining('quá xa'), findsNothing);
    await tester.tap(find.text('Xem tất cả 5 kho'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết sản phẩm'), findsOneWidget);
    expect(find.text('Kho C · WH-C'), findsOneWidget);
    expect(find.text('Kho A · WH-A'), findsOneWidget);
    expect(find.text('Ưu đãi mùa hè'), findsOneWidget);
    expect(find.text('internal-promotion-id'), findsNothing);
    expect(find.textContaining('quá xa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reports unavailable delivery when all serviceable warehouses have zero stock or none exist',
      (tester) async {
    for (final warehouses in [
      <WarehouseAvailability>[],
      [
        const WarehouseAvailability(
            id: 'far',
            code: 'FAR',
            name: 'Kho quá xa',
            quantity: 0,
            unavailableReason: 'OutsideServiceRadius')
      ],
      [
        const WarehouseAvailability(
            id: 'near',
            code: 'NEAR',
            name: 'Kho gần',
            quantity: 0,
            unavailableReason: 'BelowMlor')
      ],
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: WarehouseStockList(warehouses: warehouses))));
      expect(find.text('Không có hàng đủ điều kiện để giao.'),
          warehouses.isEmpty ? findsNothing : findsOneWidget);
      if (warehouses.isEmpty) {
        expect(find.text('Chưa có dữ liệu chi tiết theo kho.'), findsOneWidget);
      }
      expect(find.textContaining('quá xa'), findsNothing);
      expect(tester.takeException(), isNull);
    }
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
