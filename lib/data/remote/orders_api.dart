import 'package:fscm_mobile/data/remote/backend_catalog.dart';
import 'package:uuid/uuid.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
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
  OrdersApi(this._client, {bool useMock = Env.useMock}) : _useMock = useMock;

  final ApiClient _client;
  final bool _useMock;
  final Expando<String> _creationKeys = Expando<String>();

  Future<Map<String, dynamic>> _wireBody(
      String key, String retailer, String payment, List<CartLine> lines) async {
    final retailerId =
        await resolveCatalogId(_client, Endpoints.retailers, 'code', retailer);
    final wireLines = <Map<String, dynamic>>[];
    for (final line in lines) {
      wireLines.add({
        'productId': await resolveCatalogId(
            _client, Endpoints.products, 'sku', line.sku),
        'quantity': line.qty
      });
    }
    return {
      'clientOrderKey': key,
      'retailerId': retailerId,
      'paymentMethod': payment,
      'lines': wireLines
    };
  }

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
    final key = request.clientOrderKey ??
        (_creationKeys[request] ??= const Uuid().v4());
    final body = _useMock
        ? request.toJson()
        : await _wireBody(
            key, request.retailerCode, request.payment.code, request.lines);
    final data = await _client.post(Endpoints.orders, body: body);
    return Order.fromJson(asMap(data));
  }

  Future<Order> cancel(String code) async {
    final current =
        _useMock ? null : asMap(await _client.get(Endpoints.order(code)));
    final data = await _client.post(Endpoints.orderCancel(code),
        body: current == null ? null : {'expectedVersion': current['version']});
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
    if (!_useMock) {
      final results = <OrderSyncResult>[];
      for (final order in orders) {
        try {
          final body = await _wireBody(order.clientRequestId,
              order.retailerCode, order.payment.code, order.lines);
          if (!order.onlineAttempt) {
            body['offlineEstimatedAmount'] = order.localFinal;
          }
          final data = asMap(await _client.post(
              order.onlineAttempt ? Endpoints.orders : Endpoints.ordersSync,
              body: body));
          results.add(OrderSyncResult(
              clientRequestId: order.clientRequestId,
              accepted: true,
              orderCode: asStr(data['orderCode']),
              finalAmount: asInt(data['finalAmount']),
              promoChanged: asBool(data['hasOfflineDifference'])));
        } on ApiException catch (error) {
          if (error.isRetryable) rethrow;
          results.add(OrderSyncResult(
              clientRequestId: order.clientRequestId,
              accepted: false,
              reason: error.message));
        }
      }
      return results;
    }
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
