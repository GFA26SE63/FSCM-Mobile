import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_delivery_progress.dart';

void main() {
  test(
      'retailer pagination loads only requested pages and preserves server search',
      () async {
    final transport = _OrdersTransport((request) {
      final page = request.query!['page'] as int;
      return ApiResponse(statusCode: 200, data: {
        'page': page,
        'pageSize': 20,
        'totalCount': 21,
        'items': [
          for (var i = page == 1 ? 1 : 21; i <= (page == 1 ? 20 : 21); i++)
            {
              'id': 'order-$i',
              'orderCode': 'DH-$i',
              'status': 'Quoted',
              'lineCount': 2,
              'totalCartons': 30
            }
        ],
      });
    });
    final client =
        ApiClient(transport: transport, tokenReader: () => 'retailer-token');
    final controller = RetailerOrdersController(OrdersApi(client),
        search: 'DH', isCurrentUser: () => true);
    addTearDown(controller.dispose);
    addTearDown(client.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.requireValue.orders.length, 20);
    expect(transport.requests.length, 1);
    expect(controller.state.requireValue.hasMore, isTrue);
    await controller.loadMore();
    expect(controller.state.requireValue.orders.length, 21);
    expect(controller.state.requireValue.hasMore, isFalse);
    expect(transport.requests.map((request) => request.query!['page']), [1, 2]);
    expect(
        transport.requests.every((request) =>
            request.query!['pageSize'] == 20 &&
            request.query!['search'] == 'DH'),
        isTrue);
    expect(controller.state.requireValue.orders.first.itemsSummary,
        '2 SKU · 30 thùng');
  });

  test('late page response cannot overwrite refreshed retailer orders',
      () async {
    final old = Completer<ApiResponse>();
    var calls = 0;
    final transport = _OrdersTransport((request) {
      calls++;
      if (calls == 1) {
        return old.future;
      }
      return const ApiResponse(statusCode: 200, data: {
        'page': 1,
        'pageSize': 20,
        'totalCount': 1,
        'items': [
          {'id': 'new', 'orderCode': 'DH-NEW'}
        ],
      });
    });
    final client =
        ApiClient(transport: transport, tokenReader: () => 'retailer-token');
    final controller = RetailerOrdersController(OrdersApi(client),
        search: '', isCurrentUser: () => true);
    addTearDown(controller.dispose);
    addTearDown(client.dispose);
    await controller.refresh();
    old.complete(const ApiResponse(statusCode: 200, data: {
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'items': [
        {'id': 'old', 'orderCode': 'DH-OLD'}
      ],
    }));
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.requireValue.orders.single.code, 'DH-NEW');
  });

  test(
      'timeline falls back to status when reason is empty and tracking survives cache',
      () {
    final order = Order.fromJson({
      'id': 'order-1',
      'retailerId': 'retailer-1',
      'allocationState': 'Succeeded',
      'allocationResult': 'Allocated',
      'finalPricePendingAllocation': true,
      'history': [
        {
          'toStatus': 'Quoted',
          'reason': '',
          'changedAt': '2026-11-09T10:00:00Z'
        }
      ],
    });
    expect(order.timeline.single.label, 'Chờ xác nhận báo giá');
    final restored = Order.fromJson(order.toJson());
    expect(restored.retailerId, 'retailer-1');
    expect(restored.allocationState, 'Succeeded');
    expect(restored.finalPricePendingAllocation, isTrue);
  });

  test('receipt sends actual batch quantities and keeps its idempotency key',
      () async {
    final transport = _OrdersTransport((request) {
      if (request.method == 'POST') {
        return const ApiResponse(statusCode: 200, data: {});
      }
      return const ApiResponse(statusCode: 200, data: {
        'id': 'order-1',
        'orderCode': 'DH-1',
        'status': 'Delivering',
      });
    });
    final client =
        ApiClient(transport: transport, tokenReader: () => 'retailer-token');
    addTearDown(client.dispose);
    final shipment = DeliveryShipment.fromJson({
      'id': 'shipment-1',
      'shipmentCode': 'GH-1',
      'status': 'Delivering',
      'version': 7,
      'lines': [
        {
          'orderLineId': 'line-1',
          'batchId': 'batch-1',
          'sku': 'SKU-1',
          'batchCode': 'LO-1',
          'quantity': 10,
        }
      ],
    });

    await OrdersApi(client).confirmShipmentReceipt(
      'order-1',
      shipment,
      labelCodes: const ['TEM-000001'],
      operationKey: 'receipt-key-1',
      note: '2 thùng bị móp',
      lines: const [
        ShipmentReceiptLineInput(
          orderLineId: 'line-1',
          batchId: 'batch-1',
          receivedQuantity: 8,
          damagedQuantity: 2,
        ),
      ],
    );

    final receipt = transport.requests.first;
    final body = receipt.body as Map<String, dynamic>;
    expect(receipt.headers['Idempotency-Key'], 'receipt-key-1');
    expect(body['note'], '2 thùng bị móp');
    expect(body['lines'], [
      {
        'orderLineId': 'line-1',
        'batchId': 'batch-1',
        'receivedQuantity': 8.0,
        'damagedQuantity': 2.0,
      }
    ]);
  });

  testWidgets(
      'each warehouse shipment retains its own delivery and receipt progress',
      (tester) async {
    final order = Order.fromJson({'id': 'order-1', 'status': 'Delivering'});
    final shipments = [
      DeliveryShipment.fromJson({
        'id': 's1',
        'shipmentCode': 'GH-1',
        'warehouseName': 'Kho A',
        'status': 'Received',
        'totalQuantity': 10,
        'receivedQuantity': 10
      }),
      DeliveryShipment.fromJson({
        'id': 's2',
        'shipmentCode': 'GH-2',
        'warehouseName': 'Kho B',
        'status': 'Delivering',
        'totalQuantity': 20,
        'receivedQuantity': 0,
        'driverName': 'Tài xế B',
        'plateNumber': '51A-12345'
      }),
    ];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          deliveryShipmentsProvider('order-1')
              .overrideWith((ref) async => shipments),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: RetailerDeliveryProgress(order: order),
        )))));
    await tester.pumpAndSettle();
    expect(find.text('Kho A'), findsOneWidget);
    expect(find.text('Kho B'), findsOneWidget);
    expect(find.text('Đã nhận hàng'), findsOneWidget);
    expect(find.text('Đang giao'), findsOneWidget);
    expect(find.text('51A-12345'), findsOneWidget);
    expect(find.text('Chọn phần giao và quét nhận hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _OrdersTransport implements ApiTransport {
  _OrdersTransport(this.handler);
  final FutureOr<ApiResponse> Function(ApiRequest) handler;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return await handler(request);
  }
}
