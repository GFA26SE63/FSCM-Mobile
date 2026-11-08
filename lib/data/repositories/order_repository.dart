import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/local/daos/inventory_snapshot_dao.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/pricing/offline_condition_builder.dart';

/// Orders for the list screens plus whether the server was unreachable.
class OrderListResult {
  const OrderListResult({required this.orders, this.offlineOnly = false});

  final List<Order> orders;

  /// True when the server could not be reached: only orders stored on this
  /// device (offline queue) are shown.
  final bool offlineOnly;
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    api: ref.watch(ordersApiProvider),
    queue: ref.watch(offlineOrderDaoProvider),
    inventory: ref.watch(inventorySnapshotDaoProvider),
    syncState: ref.watch(syncStateDaoProvider),
    device: ref.watch(deviceIdentityProvider),
  );
});

/// Orders of the signed-in user (Sales: area/group, Retailer: own).
final ordersProvider = FutureProvider.autoDispose<OrderListResult>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const OrderListResult(orders: <Order>[]);
  return ref
      .watch(orderRepositoryProvider)
      .listOrders(includeQueue: user.role == UserRole.sales);
});

/// One order by code; offline codes (`OFF-...`) are resolved from the queue.
final orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, code) async {
  ref.watch(dataVersionProvider);
  return ref.watch(orderRepositoryProvider).getOrder(code);
});

final deliveryShipmentsProvider = FutureProvider.autoDispose
    .family<List<DeliveryShipment>, String>((ref, orderId) async {
  ref.watch(dataVersionProvider);
  return ref.watch(orderRepositoryProvider).deliveryShipments(orderId);
});

/// Entire offline queue (newest first) for the sync screen and badges.
final offlineQueueProvider =
    FutureProvider.autoDispose<List<OfflineOrder>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(offlineOrderDaoProvider).all();
});

class OrderRepository {
  OrderRepository({
    required OrdersApi api,
    required OfflineOrderDao queue,
    required InventorySnapshotDao inventory,
    required SyncStateDao syncState,
    required DeviceIdentity device,
  })  : _api = api,
        _queue = queue,
        _inventory = inventory,
        _syncState = syncState,
        _device = device;

  final OrdersApi _api;
  final OfflineOrderDao _queue;
  final InventorySnapshotDao _inventory;
  final SyncStateDao _syncState;
  final DeviceIdentity _device;

  // ------------------------------------------------------------------ read

  Future<OrderListResult> listOrders({bool includeQueue = false}) async {
    var remote = <Order>[];
    var offlineOnly = false;
    try {
      remote = await _api.list(size: 100);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      offlineOnly = true;
    }
    if (!includeQueue) {
      return OrderListResult(orders: remote, offlineOnly: offlineOnly);
    }

    final entries = await _queue.all();
    final remoteOffline =
        remote.map((o) => o.offlineCode).where((c) => c.isNotEmpty).toSet();
    final local = entries
        .where((e) => !remoteOffline.contains(e.localCode))
        .where((e) => offlineOnly || e.status != SyncStatus.synced)
        .map(orderFromOffline)
        .toList();
    final merged = <Order>[...local, ...remote]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return OrderListResult(orders: merged, offlineOnly: offlineOnly);
  }

  Future<Order> getOrder(String code) async {
    if (IdFormat.isOfflineOrder(code)) {
      final entry = await _queue.byLocalCode(code);
      if (entry == null) throw const ApiException.notFoundLocal();
      if (entry.status == SyncStatus.synced &&
          entry.serverOrderCode.isNotEmpty) {
        return getOrder(entry.serverOrderCode);
      }
      return orderFromOffline(entry);
    }
    return _api.get(code);
  }

  // ---------------------------------------------------------------- create

  Future<Order> createOnline(NewOrderRequest request) => _api.create(request);

  /// Stores an order locally (no network). It keeps `OFF-{device}-{0000}`
  /// and a UUID idempotency key until the sync service pushes it.
  Future<OfflineOrder> createOffline({
    required Retailer retailer,
    required List<CartLine> lines,
    required PriceQuote estimate,
    required DateTime estimatedAt,
    required SyncSnapshot? snapshot,
  }) async {
    if (!estimate.isComplete || estimate.lines.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Chưa đủ giá để lưu bản tạm tính offline.',
      );
    }

    final requested = <String, int>{};
    for (final line in lines) {
      requested.update(
        line.sku,
        (quantity) => quantity + line.qty,
        ifAbsent: () => line.qty,
      );
    }

    if (estimate.lines.length != requested.length ||
        estimate.lines.any(
          (line) => requested[line.sku] != line.qty,
        )) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Giỏ hàng đã thay đổi. Vui lòng kiểm tra giá lại.',
      );
    }

    if (snapshot == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Chưa có snapshot để lưu điều kiện giá/MLOR.',
      );
    }

    final expectedConditions = OfflineConditionBuilder.capture(
      snapshot: snapshot,
      retailerId: retailer.id,
      lines: lines,
      at: estimatedAt,
    );
    final seq = await _syncState.nextOfflineSeq();
    final now = AppClock.now();

    final payload = OfflineOrderPayload(
      clientRequestId: const Uuid().v4(),
      offlineCode: IdFormat.offlineOrder(_device.deviceCode, seq),
      retailerId: retailer.id,
      retailerCode: retailer.code,
      retailerName: retailer.name,
      createdAt: now,
      creditTerm: retailer.creditTerm,
      lines: List<CartLine>.unmodifiable(lines),
      localTotal: estimate.total,
      localDiscount: estimate.discount,
      localPromoIds: estimate.applied.map((promo) => promo.id).toList(),
      localQuote: estimate,
      estimatedAt: estimatedAt,
      snapshotVersion: snapshot.version,
      expectedConditions: expectedConditions,
    );

    final entry = OfflineOrder(
      clientRequestId: payload.clientRequestId,
      payload: payload,
      status: SyncStatus.pending,
      createdAt: now,
    );

    await _queue.insert(entry);

    // Giữ phần bookkeeping hiện có.
    for (final line in lines) {
      await _inventory.deduct(line.sku, line.qty);
    }

    return entry;
  }

  // --------------------------------------------------------------- actions

  Future<Order> cancel(String orderId, int expectedVersion) =>
      _api.cancel(orderId, expectedVersion);

  /// "Xóa khỏi hàng đợi đồng bộ": only for orders not sent yet.
  Future<void> removeFromQueue(String clientRequestId) =>
      _queue.delete(clientRequestId);

  Future<List<DeliveryShipment>> deliveryShipments(String orderId) =>
      _api.deliveryShipments(orderId);

  Future<Order> confirmShipmentReceipt(
    String orderId,
    DeliveryShipment shipment, {
    required List<String> labelCodes,
  }) =>
      _api.confirmShipmentReceipt(orderId, shipment, labelCodes: labelCodes);
}
