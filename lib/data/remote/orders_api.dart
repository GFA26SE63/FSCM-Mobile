import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receipt_confirmation.dart';

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

  Future<Order> get(String code) async {
    final data = await _client.get(Endpoints.order(code));
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

  /// Retailer scans the QR on the shipment: confirms delivery + earns points.
  Future<ReceiptConfirmation> confirmReceipt(
    String code, {
    required String qrToken,
    required List<String> labelCodes,
  }) async {
    final data = await _client.post(
      Endpoints.orderConfirmReceipt(code),
      body: <String, dynamic>{'qrToken': qrToken, 'labelCodes': labelCodes},
    );
    return ReceiptConfirmation.fromJson(asMap(data));
  }
}
