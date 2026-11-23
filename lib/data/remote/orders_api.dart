import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:uuid/uuid.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/data/models/order_page.dart';

final ordersApiProvider =
    Provider<OrdersApi>((ref) => OrdersApi(ref.watch(apiClientProvider)));

class OrdersApi {
  OrdersApi(this._client) : _graphQl = GraphQlClient(_client);

  final ApiClient _client;
  final GraphQlClient _graphQl;

  // READ via `entities.orderReads` / `orderRead`: same OrderService and the
  // same role scope as REST GET /orders. Only fields the app reads are
  // selected (no MLOR snapshot, allocation scores or audit). Writes stay REST.
  static const String _summaryFields = '''
    id orderCode retailerId retailerCode retailerName status paymentMethod
    finalAmount finalPricePendingAllocation allocationState allocationResult
    shipmentCount totalCartons lineCount source version createdAt''';

  static const String _detailFields = '''
    id orderCode retailerId retailerCode retailerName status paymentMethod
    subtotalAmount discountAmount finalAmount finalPricePendingAllocation
    allocationState allocationResult creditTermDays rejectionReason
    offlineEstimatedAmount hasOfflineDifference source version createdAt
    payment { method status dueDate }
    history { toStatus reason changedAt }
    lines {
      sku productName quantity unitPrice grossAmount discountAmount
      discountPercent discountSourceType discountSourceCode
      ordinaryPromotion { promotionId code name discountAmount }
      allocationFragments {
        batchCode quantity batchExpirationDate warehouseCode listUnitPrice
        ordinaryPromotionDiscountPerUnit baseUnitPrice
        remainingShelfLifePercent shelfLifeDiscountPerUnit finalUnitPrice
        netAmount discountReason estimatedArrivalAt
      }
      allocations {
        batchCode quantity warehouseCode estimatedArrivalAt netAmount
      }
    }''';

  /// No `sort` argument: the Backend default is newest first. The query has no
  /// createdAt/id ordering, so none is requested.
  static const String _pageQuery = '''
    query Orders(\$status: String, \$search: String, \$page: Int!, \$pageSize: Int!) {
      entities {
        orderReads(status: \$status, search: \$search, page: \$page, pageSize: \$pageSize) {
          items { $_summaryFields }
          page pageSize totalCount
        }
      }
    }''';

  Future<OrderPage> _readPage({
    String? status,
    String? search,
    required int page,
    required int size,
  }) async {
    final data = await _graphQl.query(
      _pageQuery,
      operationName: 'Orders',
      variables: <String, dynamic>{
        'status': status,
        'search': search,
        'page': page,
        'pageSize': size,
      },
    );
    return OrderPage.fromJson(asMap(asMap(data['entities'])['orderReads']));
  }

  Future<Order> retryAllocation(String id, int version) async =>
      Order.fromJson(asMap(await _client.post('/orders/$id/allocation/retry',
          body: {'expectedVersion': version})));

  /// Default page size of every order list (Sales and Retailer).
  static const int defaultPageSize = 10;

  Future<OrderPage> listPage(
          {int page = 1,
          int pageSize = defaultPageSize,
          String? search,
          String? status}) =>
      _readPage(
        status: status,
        page: page,
        size: pageSize,
        search:
            (search != null && search.trim().isNotEmpty) ? search.trim() : null,
      );

  /// Statuses the Backend order-list filter accepts (OrderService.OrderStatusSet
  /// in the Backend source). Picking, Issued, Delivering, Delivered and
  /// Completed are NOT accepted there: `orderReads(status:)` and REST
  /// `GET /orders?status=` answer "Order status filter is invalid".
  static const Set<String> listFilterStatuses = <String>{
    'Allocating',
    'Quoted',
    'AllocationFailed',
    'OutOfStock',
    'AllocationConflict',
    'Withdrawn',
    'QuoteRejected',
    'QuoteExpired',
    'PaymentPending',
    'ConvertedToPo',
  };

  /// Orders per status within the caller's scope in ONE request: the
  /// `totalCount` of a one-row page, never counted from a partial list.
  ///
  /// Statuses the list filter accepts go through `orderReads` (same service
  /// and scope as REST). The others are counted on `entities.salesOrders`; for
  /// Sales pass [ownerUserId]: that entity also shows group orders, and the
  /// filter narrows it to the user's own orders, which is the REST scope.
  Future<Map<String, int>> countsByStatus(
    List<String> statuses, {
    String? ownerUserId,
  }) async {
    if (statuses.isEmpty) return <String, int>{};
    final viaEntity = <int>{
      for (var i = 0; i < statuses.length; i++)
        if (!listFilterStatuses.contains(statuses[i])) i,
    };
    final declarations = <String>[
      for (var i = 0; i < statuses.length; i++) '\$s$i: String!',
      if (viaEntity.isNotEmpty && ownerUserId != null) '\$uid: UUID!',
    ].join(', ');
    final owner =
        ownerUserId == null ? '' : '{ createdByUserId: { eq: \$uid } }, ';
    final fields = <String>[
      for (var i = 0; i < statuses.length; i++)
        viaEntity.contains(i)
            ? 'c$i: salesOrders(first: 1, where: { and: [$owner'
                '{ status: { eq: \$s$i } }] }) { totalCount }'
            : 'c$i: orderReads(status: \$s$i, page: 1, pageSize: 1) '
                '{ totalCount }',
    ].join(' ');
    final data = await _graphQl.query(
      'query OrderCounts($declarations) { entities { $fields } }',
      operationName: 'OrderCounts',
      variables: <String, dynamic>{
        for (var i = 0; i < statuses.length; i++) 's$i': statuses[i],
        if (viaEntity.isNotEmpty && ownerUserId != null) 'uid': ownerUserId,
      },
    );
    final entities = asMap(data['entities']);
    final counts = <String, int>{};
    for (var i = 0; i < statuses.length; i++) {
      final total = asMap(entities['c$i'])['totalCount'];
      if (total is! num) {
        throw const ApiException(
            kind: ApiErrorKind.server,
            message: 'Phản hồi đếm đơn hàng không hợp lệ.');
      }
      counts[statuses[i]] = total.toInt();
    }
    return counts;
  }

  /// Exact number of the user's own orders created in [from, to) (server
  /// aggregate), optionally limited to [statuses]. Own-orders scope equals the
  /// REST Sales scope (`CreatedByUserId == actor`).
  Future<int> countOwnOrdersCreated({
    required String ownerUserId,
    required DateTime from,
    required DateTime to,
    List<String>? statuses,
  }) async {
    final withStatus = statuses != null && statuses.isNotEmpty;
    final data = await _graphQl.query(
      'query OwnOrdersCreated(\$uid: UUID!, \$from: DateTime!, '
      '\$to: DateTime!${withStatus ? ', \$st: [String!]!' : ''}) '
      '{ entities { n: salesOrders(first: 1, where: { and: ['
      '{ createdByUserId: { eq: \$uid } }, '
      '{ createdAt: { gte: \$from } }, { createdAt: { lt: \$to } }'
      '${withStatus ? ', { status: { in: \$st } }' : ''}]}) '
      '{ totalCount } } }',
      operationName: 'OwnOrdersCreated',
      variables: <String, dynamic>{
        'uid': ownerUserId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (withStatus) 'st': statuses,
      },
    );
    final total = asMap(asMap(data['entities'])['n'])['totalCount'];
    if (total is! num) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Phản hồi đếm đơn hàng không hợp lệ.');
    }
    return total.toInt();
  }

  /// Number of orders in [status] within the caller's scope.
  Future<int> countByStatus(String status) async =>
      (await countsByStatus(<String>[status]))[status]!;

  /// Sales: own + group orders. Retailer: own orders (scoped by the token).
  Future<List<Order>> list({
    String? status,
    String? search,
    int page = 1,
    int size = 50,
  }) async =>
      (await _readPage(status: status, search: search, page: page, size: size))
          .items;

  Future<Map<String, int>> availability(
      String retailerId, List<String> productIds) async {
    final products = await availabilityByWarehouse(retailerId, productIds);
    return products.map((sku, item) => MapEntry(sku, item.quantity));
  }

  Future<Map<String, ProductAvailability>> availabilityByWarehouse(
      String retailerId, List<String> productIds) async {
    final quantities = <String, ProductAvailability>{};
    for (var offset = 0; offset < productIds.length; offset += 100) {
      final requestedIds = productIds.skip(offset).take(100).toSet().toList();
      final data = asMap(await _client.post('/orders/availability', body: {
        'retailerId': retailerId,
        'productIds': requestedIds,
      }));
      if (data['items'] is! List ||
          unwrapItems(data).length != requestedIds.length) {
        throw const ApiException(
            kind: ApiErrorKind.server,
            message: 'Phản hồi kiểm tra tồn thiếu dữ liệu sản phẩm.');
      }
      for (final item in unwrapItems(data)) {
        final quantity = item['eligibleQuantity'];
        if (asStr(item['sku']).isEmpty ||
            quantity is! num ||
            !quantity.isFinite ||
            quantity < 0) {
          throw const ApiException(
              kind: ApiErrorKind.server,
              message: 'Phản hồi kiểm tra tồn có số lượng không hợp lệ.');
        }
        final availability = ProductAvailability.fromJson(item,
            checkedAt: asDate(data['checkedAt']));
        quantities[availability.sku] = availability;
      }
    }
    return quantities;
  }

  Future<Order> get(String idOrCode) async {
    final isId = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(idOrCode);
    // By code there is no GraphQL lookup, so that stays REST.
    if (!isId) {
      return Order.fromJson(
          asMap(await _client.get(Endpoints.orderByCode(idOrCode))));
    }
    try {
      // The id is a validated GUID, so it is safe to inline as the literal.
      final data = await _graphQl.query(
        'query OrderDetail { entities { orderRead(id: "$idOrCode") '
        '{ $_detailFields } } }',
        operationName: 'OrderDetail',
      );
      return Order.fromJson(asMap(asMap(data['entities'])['orderRead']));
    } on ApiException catch (error) {
      // GraphQL hides domain errors (not found / forbidden) behind a generic
      // message. Anything but a network or auth failure is re-read through
      // REST, which answers with the precise status.
      if (error.isNetwork ||
          error.kind == ApiErrorKind.unauthorized ||
          error.kind == ApiErrorKind.forbidden) {
        rethrow;
      }
      return Order.fromJson(
          asMap(await _client.get(Endpoints.order(idOrCode))));
    }
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
      if (payload.pendingOnlineRequest == null &&
          !payload.hasCompleteExpectedConditions) {
        results.add(
          OrderSyncResult(
            clientRequestId: payload.clientRequestId,
            accepted: false,
            reason:
                'Bản nháp thiếu điều kiện giá/hạn sử dụng tối thiểu tại thời điểm lưu. '
                'Hãy tạo bản nháp mới sau khi kiểm tra dữ liệu đồng bộ; '
                'bản cũ được giữ lại để đối chiếu.',
          ),
        );
        continue;
      }
      results.add(await submitOffline(payload));
    }
    return results;
  }

  Future<OrderSyncResult> submitOffline(
    OfflineOrderPayload payload, {
    bool confirmConditionChanges = false,
  }) async {
    final data = await _client.post(
      payload.pendingOnlineRequest == null
          ? Endpoints.ordersSync
          : Endpoints.orders,
      body: payload.toRequestJson(
        confirmConditionChanges: confirmConditionChanges,
      ),
    );
    final order = Order.fromJson(asMap(data));
    return OrderSyncResult(
      serverOrder: order,
      clientRequestId: payload.clientRequestId,
      accepted: true,
      orderCode: order.code,
      finalAmount: order.finalAmount,
      promoChanged: order.finalAmount != payload.localFinal,
      changeReason: order.finalAmount == payload.localFinal
          ? ''
          : 'Giá dự kiến được máy chủ tính lại khi nhận đơn. '
              'Giá sau giảm HSD được xác định khi phân bổ.',
    );
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
