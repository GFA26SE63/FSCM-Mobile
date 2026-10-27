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
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/allocation_result.dart';
import 'package:fscm_mobile/data/models/receipt_confirmation.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

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
    catalog: ref.watch(catalogRepositoryProvider),
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

/// F90 result is separate from the order read because it is published only
/// after plan approval and carries the immutable per-line outcome.
final allocationResultProvider = FutureProvider.autoDispose
    .family<AllocationRunResult, String>((ref, orderId) async {
  return ref.watch(orderRepositoryProvider).allocationResult(orderId);
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
    required CatalogRepository catalog,
  })  : _api = api,
        _queue = queue,
        _inventory = inventory,
        _syncState = syncState,
        _device = device,
        _catalog = catalog;

  final OrdersApi _api;
  final OfflineOrderDao _queue;
  final InventorySnapshotDao _inventory;
  final SyncStateDao _syncState;
  final DeviceIdentity _device;
  final CatalogRepository _catalog;

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
    final catalog = await _catalog.load();
    final remoteOffline =
        remote.map((o) => o.offlineCode).where((c) => c.isNotEmpty).toSet();
    final local = entries
        .where((e) => !remoteOffline.contains(e.localCode))
        .where((e) => offlineOnly || e.status != SyncStatus.synced)
        .map((e) => _toOrder(e, catalog))
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
      return _toOrder(entry, await _catalog.load());
    }
    return _api.get(code);
  }

  Future<AllocationRunResult> allocationResult(String orderId) =>
      _api.allocationResult(orderId);

  Order _toOrder(OfflineOrder entry, CatalogData catalog) {
    final quote =
        catalog.quote(entry.payload.lines, entry.payload.retailerCode);
    return orderFromOffline(
      entry,
      productNames: <String, String>{
        for (final p in catalog.products) p.sku: p.name
      },
      unitPrices: catalog.prices,
      localQuote: quote,
    );
  }

  // ---------------------------------------------------------------- create

  Future<Order> createOnline(NewOrderRequest request) => _api.create(request);

  /// Stores an order locally (no network). It keeps `OFF-{device}-{0000}`
  /// and a UUID idempotency key until the sync service pushes it.
  Future<OfflineOrder> createOffline({
    required Retailer retailer,
    required List<CartLine> lines,
    required PaymentMethod payment,
  }) async {
    final catalog = await _catalog.load();
    final seq = await _syncState.nextOfflineSeq();
    final quote = catalog.quote(lines, retailer.code);
    final now = AppClock.now();
    final payload = OfflineOrderPayload(
      clientRequestId: const Uuid().v4(),
      offlineCode: IdFormat.offlineOrder(_device.deviceCode, seq),
      retailerCode: retailer.code,
      retailerName: retailer.name,
      createdAt: now,
      payment: payment,
      creditTerm: payment == PaymentMethod.credit ? retailer.creditTerm : 0,
      lines: lines,
      localTotal: quote.total,
      localDiscount: quote.discount,
      localPromoIds: quote.applied.map((a) => a.id).toList(),
    );
    final entry = OfflineOrder(
      clientRequestId: payload.clientRequestId,
      payload: payload,
      status: SyncStatus.pending,
      createdAt: now,
    );
    await _queue.insert(entry);
    for (final l in lines) {
      await _inventory.deduct(l.sku, l.qty);
    }
    return entry;
  }

  // --------------------------------------------------------------- actions

  Future<Order> cancel(String code) => _api.cancel(code);

  /// "Xóa khỏi hàng đợi đồng bộ": only for orders not sent yet.
  Future<void> removeFromQueue(String clientRequestId) =>
      _queue.delete(clientRequestId);

  Future<ReceiptConfirmation> confirmReceipt(
    String code, {
    required List<String> labelCodes,
  }) =>
      _api.confirmReceipt(code,
          qrToken: labelCodes.first, labelCodes: labelCodes);
}
