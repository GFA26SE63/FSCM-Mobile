import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/allocation_result.dart';
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

  Future<Order> cancel(String code) async {
    final data = await _client.post(Endpoints.orderCancel(code));
    return Order.fromJson(asMap(data));
  }

  /// F90: the approved allocation decision, including Released/Short lines.
  Future<AllocationRunResult> allocationResult(String orderId) async {
    final data = await _client.get(Endpoints.allocationRunOrderResult(orderId));
    return AllocationRunResult.fromJson(asMap(data));
  }

  /// `POST /orders/sync`: the server processes the batch in the order given
  /// (arrival order), re-prices every order and answers one result each.
  Future<List<OrderSyncResult>> syncOffline(
      List<OfflineOrderPayload> orders) async {
    final data = await _client.post(
      Endpoints.ordersSync,
      body: <String, dynamic>{'orders': orders.map((o) => o.toJson()).toList()},
    );
    return asMapList(asMap(data)['results'])
        .map(OrderSyncResult.fromJson)
        .toList();
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
