import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:uuid/uuid.dart';

final ordersApiProvider =
    Provider<OrdersApi>((ref) => OrdersApi(ref.watch(apiClientProvider)));

class OrdersApi {
  OrdersApi(this._client);

  final ApiClient _client;

  /// Sales: own + group orders. Retailer: own orders (scoped by the token).
  Future<List<Order>> list({
    String? status,
    String? search,
    int page = 1,
    int size = 50,
  }) async {
    final data = await _client.get(
      Endpoints.orders,
      query: <String, dynamic>{
        'status': status,
        'search': search,
        'page': page,
        'size': size,
      },
    );
    return unwrapItems(data).map(Order.fromJson).toList();
  }

  Future<Order> get(String idOrCode) async {
    final isId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(idOrCode);
    final data = await _client.get(
      isId ? Endpoints.order(idOrCode) : Endpoints.orderByCode(idOrCode),
    );
    return Order.fromJson(asMap(data));
  }

  /// Online order creation (promotion + allocation computed by the server).
  Future<Order> create(NewOrderRequest request) async {
    final data = await _client.post(Endpoints.orders, body: request.toJson());
    return Order.fromJson(asMap(data));
  }

  Future<Order> cancel(String orderId, int expectedVersion) async {
    final data = await _client.post(
      Endpoints.orderCancel(orderId),
      body: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'reason': 'Sales withdrew the SO before allocation completed.',
      },
    );
    return Order.fromJson(asMap(data));
  }

  /// The current API accepts one idempotent offline SO per request. Process
  /// the local queue in creation order so server priority remains deterministic.
  Future<List<OrderSyncResult>> syncOffline(
      List<OfflineOrderPayload> orders) async {
    final results = <OrderSyncResult>[];
    for (final payload in orders) {
      final data = await _client.post(Endpoints.ordersSync, body: payload.toJson());
      final order = Order.fromJson(asMap(data));
      results.add(OrderSyncResult(
        clientRequestId: payload.clientRequestId,
        accepted: true,
        orderCode: order.code,
        finalAmount: order.finalAmount,
        promoChanged: order.finalAmount != payload.localFinal,
        changeReason: order.finalAmount == payload.localFinal
            ? ''
            : 'Giá/khuyến mãi được tính lại khi đồng bộ.',
      ));
    }
    return results;
  }

  Future<List<DeliveryShipment>> deliveryShipments(String orderId) async {
    final delivery =
        asMap(await _client.get(Endpoints.shipmentDeliveryView(orderId)));
    return asMapList(delivery['shipments'])
        .map(DeliveryShipment.fromJson)
        .toList(growable: false);
  }

  /// Confirms the warehouse shipment explicitly selected by the retailer.
  Future<Order> confirmShipmentReceipt(
    String orderId,
    DeliveryShipment shipment, {
    required List<String> labelCodes,
  }) async {
    if (!shipment.canReceive) {
      throw const ApiException(
        kind: ApiErrorKind.conflict,
        message: 'Không có phần giao nào đang vận chuyển để xác nhận.',
      );
    }
    final lines = shipment.lines
        .map((line) => <String, dynamic>{
              'orderLineId': line.orderLineId,
              'batchId': line.batchId,
              'receivedQuantity': line.quantity,
              'damagedQuantity': 0,
            })
        .toList();
    await _client.post(
      Endpoints.shipmentReceipt(shipment.id),
      body: <String, dynamic>{
        'qrCodes': labelCodes,
        'lines': lines,
        'expectedVersion': shipment.version,
        'note': 'Retailer confirmed full receipt on mobile.',
      },
      headers: <String, String>{'Idempotency-Key': const Uuid().v4()},
    );
    return get(orderId);
  }
}
