import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/pricing/offline_condition_builder.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

class OrderListResult {
  const OrderListResult({
    required this.orders,
    this.offlineOnly = false,
  });

  final List<Order> orders;
  final bool offlineOnly;
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final user = ref.watch(currentUserProvider);
  final ownerId = user?.id ?? '';

  return OrderRepository(
    api: ref.watch(ordersApiProvider),
    queue: ref.watch(offlineOrderDaoProvider),
    syncState: ref.watch(syncStateDaoProvider),
    device: ref.watch(deviceIdentityProvider),
    ownerId: ownerId,
    isSales: user?.role == UserRole.sales,
    isCurrentUser: () => ref.read(currentUserProvider)?.id == ownerId,
  );
});

final ordersProvider = FutureProvider.autoDispose<OrderListResult>((ref) async {
  ref.watch(dataVersionProvider);

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const OrderListResult(orders: <Order>[]);
  }

  return ref.watch(orderRepositoryProvider).listOrders(
        includeQueue: user.role == UserRole.sales,
      );
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, code) async {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);

  return ref.watch(orderRepositoryProvider).getOrder(code);
});

final deliveryShipmentsProvider = FutureProvider.autoDispose
    .family<List<DeliveryShipment>, String>((ref, orderId) async {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);

  return ref.watch(orderRepositoryProvider).deliveryShipments(orderId);
});

final offlineQueueProvider =
    FutureProvider.autoDispose<List<OfflineOrder>>((ref) async {
  ref.watch(dataVersionProvider);

  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.sales) {
    return const <OfflineOrder>[];
  }

  return ref.watch(offlineOrderDaoProvider).all(ownerId: user.id);
});

class OrderRepository {
  OrderRepository({
    required OrdersApi api,
    required OfflineOrderDao queue,
    required SyncStateDao syncState,
    required DeviceIdentity device,
    required String ownerId,
    required bool isSales,
    required bool Function() isCurrentUser,
  })  : _api = api,
        _queue = queue,
        _syncState = syncState,
        _device = device,
        _ownerId = ownerId,
        _isSales = isSales,
        _isCurrentUser = isCurrentUser;

  final OrdersApi _api;
  final OfflineOrderDao _queue;
  final SyncStateDao _syncState;
  final DeviceIdentity _device;
  final String _ownerId;
  final bool _isSales;
  final bool Function() _isCurrentUser;

  void _requireSession({bool salesOnly = false}) {
    if (_ownerId.isEmpty || !_isCurrentUser()) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Phiên đăng nhập đã thay đổi. Vui lòng mở lại màn hình.',
      );
    }

    if (salesOnly && !_isSales) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Chỉ Sales được quản lý draft offline.',
      );
    }
  }

  Future<OrderListResult> listOrders({
    bool includeQueue = false,
  }) async {
    _requireSession();

    var remote = <Order>[];
    var offlineOnly = false;

    try {
      remote = await _api.list(size: 100);
    } on ApiException catch (error) {
      if (!error.isNetwork) {
        rethrow;
      }

      offlineOnly = true;
    }

    _requireSession();

    if (!includeQueue || !_isSales) {
      return OrderListResult(
        orders: remote,
        offlineOnly: offlineOnly,
      );
    }

    final entries = await _queue.all(ownerId: _ownerId);
    _requireSession(salesOnly: true);

    final remoteOffline = remote
        .map((order) => order.offlineCode)
        .where((code) => code.isNotEmpty)
        .toSet();

    final local = entries
        .where((entry) => !remoteOffline.contains(entry.localCode))
        .where((entry) => !remote.any((order) =>
            order.code.isNotEmpty && order.code == entry.serverOrderCode))
        .where(
          (entry) =>
              offlineOnly ||
              entry.status != SyncStatus.synced ||
              entry.serverOrder != null,
        )
        .map(orderFromOffline)
        .toList();

    final merged = <Order>[...local, ...remote]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return OrderListResult(
      orders: merged,
      offlineOnly: offlineOnly,
    );
  }

  Future<Order> getOrder(String code) async {
    _requireSession();

    if (IdFormat.isOfflineOrder(code)) {
      _requireSession(salesOnly: true);

      final entry = await _queue.byLocalCode(
        code,
        ownerId: _ownerId,
      );

      _requireSession(salesOnly: true);

      if (entry == null) {
        throw const ApiException.notFoundLocal();
      }

      if (entry.status == SyncStatus.synced &&
          entry.serverOrderCode.isNotEmpty) {
        try {
          return await getOrder(entry.serverOrderCode);
        } on ApiException catch (error) {
          if (!error.isNetwork || entry.serverOrder == null) {
            rethrow;
          }
          _requireSession(salesOnly: true);
          return orderFromOffline(entry);
        }
      }

      return orderFromOffline(entry);
    }

    final result = await _api.get(code);
    _requireSession();

    return result;
  }

  Future<Order> createOnline(NewOrderRequest request) {
    _requireSession();
    return _api.create(request);
  }

  void _validateEstimate({
    required List<CartLine> lines,
    required PriceQuote estimate,
    required int orderStep,
  }) {
    if (orderStep <= 0 ||
        lines.isEmpty ||
        lines.any(
          (line) =>
              line.productId.isEmpty ||
              line.qty <= 0 ||
              line.qty % orderStep != 0,
        )) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: 'Giỏ hàng cần có sản phẩm và số lượng thùng nguyên dương '
            'theo bước $orderStep.',
      );
    }

    if (lines.map((line) => line.productId).toSet().length != lines.length) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Mỗi sản phẩm chỉ được có một dòng trong draft.',
      );
    }

    if (!estimate.isComplete || estimate.lines.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Chưa đủ giá để lưu bản tạm tính offline.',
      );
    }

    final requested = <String, int>{
      for (final line in lines) line.sku: line.qty,
    };

    if (estimate.lines.length != requested.length ||
        estimate.lines.any(
          (line) => requested[line.sku] != line.qty,
        )) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Giỏ hàng đã thay đổi. Vui lòng kiểm tra giá lại.',
      );
    }
  }

  Future<OfflineOrder> createOffline({
    required int orderStep,
    required Retailer retailer,
    required List<CartLine> lines,
    required PriceQuote estimate,
    required DateTime estimatedAt,
    required SyncSnapshot? snapshot,
  }) async {
    _requireSession(salesOnly: true);
    _validateEstimate(lines: lines, estimate: estimate, orderStep: orderStep);

    if (snapshot == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Chưa có snapshot để lưu điều kiện giá/MLOR.',
      );
    }

    final conditions = OfflineConditionBuilder.capture(
      snapshot: snapshot,
      retailerId: retailer.id,
      lines: lines,
      at: estimatedAt,
    );

    final sequence = await _syncState.nextOfflineSeq();
    _requireSession(salesOnly: true);

    final now = AppClock.now();
    final payload = OfflineOrderPayload(
      clientRequestId: const Uuid().v4(),
      offlineCode: IdFormat.offlineOrder(
        _device.deviceCode,
        sequence,
      ),
      retailerId: retailer.id,
      retailerCode: retailer.code,
      retailerName: retailer.name,
      createdAt: now,
      creditTerm: retailer.creditTerm,
      lines: List<CartLine>.unmodifiable(lines),
      localTotal: estimate.total,
      localDiscount: estimate.discount,
      localPromoIds: estimate.applied.map((promotion) => promotion.id).toList(),
      localQuote: estimate,
      estimatedAt: estimatedAt,
      snapshotVersion: snapshot.version,
      expectedConditions: conditions,
    );

    final entry = OfflineOrder(
      clientRequestId: payload.clientRequestId,
      payload: payload,
      status: SyncStatus.pending,
      createdAt: now,
    );

    await _queue.insert(entry, ownerId: _ownerId);
    return entry;
  }

  Future<void> editOffline({
    required int orderStep,
    required OfflineOrder original,
    required List<CartLine> lines,
    required PriceQuote estimate,
    required DateTime estimatedAt,
    required SyncSnapshot snapshot,
  }) async {
    _requireSession(salesOnly: true);
    _validateEstimate(lines: lines, estimate: estimate, orderStep: orderStep);

    final previous = original.payload;
    final conditions = OfflineConditionBuilder.capture(
      snapshot: snapshot,
      retailerId: previous.retailerId,
      lines: lines,
      at: estimatedAt,
    );

    final replacement = OfflineOrderPayload(
      clientRequestId: previous.clientRequestId,
      offlineCode: previous.offlineCode,
      retailerId: previous.retailerId,
      retailerCode: previous.retailerCode,
      retailerName: previous.retailerName,
      createdAt: previous.createdAt,
      payment: previous.payment,
      creditTerm: previous.creditTerm,
      lines: List<CartLine>.unmodifiable(lines),
      localTotal: estimate.total,
      localDiscount: estimate.discount,
      localPromoIds: estimate.applied.map((promotion) => promotion.id).toList(),
      localQuote: estimate,
      estimatedAt: estimatedAt,
      snapshotVersion: snapshot.version,
      expectedConditions: conditions,
    );

    await _queue.replaceDraft(
      ownerId: _ownerId,
      original: original,
      replacement: replacement,
    );
  }

  Future<void> removeFromQueue(String clientRequestId) {
    _requireSession(salesOnly: true);

    return _queue.deleteDraft(
      clientRequestId,
      ownerId: _ownerId,
    );
  }

  Future<Order> cancel(String orderId, int expectedVersion) {
    _requireSession();
    return _api.cancel(orderId, expectedVersion);
  }

  Future<List<DeliveryShipment>> deliveryShipments(String orderId) {
    _requireSession();
    return _api.deliveryShipments(orderId);
  }

  Future<Order> confirmShipmentReceipt(
    String orderId,
    DeliveryShipment shipment, {
    required List<String> labelCodes,
  }) {
    _requireSession();

    return _api.confirmShipmentReceipt(
      orderId,
      shipment,
      labelCodes: labelCodes,
    );
  }
}
