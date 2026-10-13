import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/remote/sync_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

enum SyncPhase { idle, pushing, pulling }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.lastError,
    this.lastSummary,
  });

  final SyncPhase phase;

  /// Last successful snapshot download.
  final DateTime? lastSyncAt;
  final String? lastError;

  /// e.g. "Đã đồng bộ 2 đơn, 1 đơn bị từ chối."
  final String? lastSummary;

  bool get busy => phase != SyncPhase.idle;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
    String? lastSummary,
  }) =>
      SyncState(
        phase: phase ?? this.phase,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
        lastSummary: lastSummary ?? this.lastSummary,
      );
}

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncState>((ref) => SyncService(ref));

/// Offline-first synchronisation for the Sales app (SPEC section 11).
///
/// 1. Push: queued offline orders go to `POST /orders/sync` in CREATION
///    order; the server result is final (accepted -> synced, rejected ->
///    rejected + reason + local notification).
/// 2. Pull: `GET /sync/snapshot` refreshes retailers, products, prices,
///    promotions and the stock summary in the local tables.
///
/// Triggers: login, connectivity regained, manual button, and a periodic
/// tick that retries failed entries whose backoff elapsed.
class SyncService extends StateNotifier<SyncState> {
  SyncService(this._ref) : super(const SyncState()) {
    _ref.listen<NetworkState>(networkMonitorProvider, (previous, next) {
      final wasOnline = previous?.online ?? false;
      if (!wasOnline && next.online) unawaited(syncAll());
    });
    _timer = Timer.periodic(Env.syncRetryTick, (_) => unawaited(_autoRetry()));
  }

  final Ref _ref;
  Timer? _timer;
  bool _running = false;

  OfflineOrderDao get _queue => _ref.read(offlineOrderDaoProvider);

  bool get _online => _ref.read(networkMonitorProvider).online;

  bool get _isSales => _ref.read(currentUserProvider)?.role == UserRole.sales;

  /// Push then pull. [manual] ignores backoff / retry limits.
  Future<void> syncAll({bool manual = false}) async {
    if (_running || !_isSales) return;
    if (!_online) {
      state =
          state.copyWith(lastError: 'Không có mạng - đơn được giữ trên máy.');
      return;
    }
    _running = true;
    try {
      await _recoverStale();
      await _push(manual: manual);
      await _pull();
    } finally {
      _running = false;
      if (mounted) state = state.copyWith(phase: SyncPhase.idle);
      _bump();
    }
  }

  /// Download only (pull-to-refresh on lists).
  Future<void> refreshSnapshot() async {
    if (_running || !_online) return;
    _running = true;
    try {
      await _pull();
    } finally {
      _running = false;
      if (mounted) state = state.copyWith(phase: SyncPhase.idle);
      _bump();
    }
  }

  Future<void> _autoRetry() async {
    if (_running || !_isSales || !_online) return;
    final entries = await _queue.byStatus(<SyncStatus>[SyncStatus.pending]);
    final due = SyncQueueLogic.dueForPush(entries, AppClock.now());
    if (due.isEmpty) return;
    _running = true;
    try {
      await _push(manual: false);
    } finally {
      _running = false;
      if (mounted) state = state.copyWith(phase: SyncPhase.idle);
      _bump();
    }
  }

  Future<void> _recoverStale() async {
    final stale = await _queue.byStatus(<SyncStatus>[SyncStatus.syncing]);
    for (final e in stale) {
      await _queue.update(SyncQueueLogic.recoverStale(e));
    }
  }

  // ------------------------------------------------------------------ push

  Future<void> _push({required bool manual}) async {
    final pending = await _queue.byStatus(<SyncStatus>[SyncStatus.pending]);
    final now = AppClock.now();
    final batch = SyncQueueLogic.dueForPush(pending, now, manual: manual);
    if (batch.isEmpty) return;

    state = state.copyWith(phase: SyncPhase.pushing, clearError: true);
    final sending = <OfflineOrder>[];
    for (final e in batch) {
      final marked = SyncQueueLogic.markSyncing(e, now);
      await _queue.update(marked);
      sending.add(marked);
    }
    _bump();

    List<OrderSyncResult> results;
    try {
      results = await _ref
          .read(ordersApiProvider)
          .syncOffline(sending.map((e) => e.payload).toList());
    } on ApiException catch (e) {
      final failedAt = AppClock.now();
      for (final s in sending) {
        if (e.isRetryable) {
          await _queue
              .update(SyncQueueLogic.markFailed(s, e.message, failedAt));
        } else {
          // The server answered with a final client error: do not retry.
          await _rejectLocally(s, e.message, failedAt, manual);
        }
      }
      state = state.copyWith(lastError: e.message);
      return;
    }

    final byId = <String, OrderSyncResult>{
      for (final r in results) r.clientRequestId: r
    };
    final doneAt = AppClock.now();
    var accepted = 0;
    var rejected = 0;
    // Apply in creation order so notifications keep that order too.
    for (final s in sending) {
      final r = byId[s.clientRequestId];
      if (r == null) {
        await _queue.update(
            SyncQueueLogic.markFailed(s, 'Máy chủ chưa trả kết quả.', doneAt));
        continue;
      }
      final updated = SyncQueueLogic.applyResult(s, r, doneAt, manual: manual);
      await _queue.update(updated);
      if (r.accepted) {
        accepted++;
      } else {
        rejected++;
        await _ref.read(notificationRepositoryProvider).addLocal(
              'Đơn ${s.localCode} bị từ chối sau khi đồng bộ: ${updated.error}',
              orderCode: r.orderCode.isEmpty ? s.localCode : r.orderCode,
            );
      }
    }
    final parts = <String>[
      if (accepted > 0) 'Đã đồng bộ $accepted đơn',
      if (rejected > 0) '$rejected đơn bị từ chối',
    ];
    state = state.copyWith(
        lastSummary: parts.isEmpty ? null : '${parts.join(', ')}.');
  }

  Future<void> _rejectLocally(
      OfflineOrder s, String message, DateTime at, bool manual) async {
    final rejected = SyncQueueLogic.applyResult(
      s,
      OrderSyncResult(
          clientRequestId: s.clientRequestId, accepted: false, reason: message),
      at,
      manual: manual,
    );
    await _queue.update(rejected);
    await _ref.read(notificationRepositoryProvider).addLocal(
          'Đơn ${s.localCode} bị từ chối: $message',
          orderCode: s.localCode,
        );
  }

  // ------------------------------------------------------------------ pull

  Future<void> _pull() async {
    state = state.copyWith(phase: SyncPhase.pulling);
    try {
      final snapshot = await _ref.read(syncApiProvider).snapshot();
      await _ref.read(catalogRepositoryProvider).applySnapshot(snapshot);
      state = state.copyWith(lastSyncAt: snapshot.serverTime);
    } on ApiException catch (e) {
      state = state.copyWith(lastError: e.message);
    }
  }

  void _bump() {
    if (!mounted) return;
    _ref.read(dataVersionProvider.notifier).state++;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
