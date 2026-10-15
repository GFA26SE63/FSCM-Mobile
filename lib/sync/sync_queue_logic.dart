import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';

/// Pure rules of the offline order queue (unit-tested, no I/O).
///
/// * Orders are pushed in CREATION order: `createdAt`, then queue id.
/// * The server processes the batch in the order received and its result is
///   FINAL: accepted orders become `synced` (with the server order code),
///   rejected ones become `rejected` with the reason - they are never
///   retried or edited.
/// * Network / 5xx failures keep the order `pending`, increase the retry
///   counter and delay the next automatic attempt (exponential backoff,
///   capped); after [maxAutoRetries] only a manual sync retries.
class SyncQueueLogic {
  SyncQueueLogic._();

  static const int maxAutoRetries = 6;
  static const Duration baseBackoff = Duration(seconds: 20);
  static const Duration maxBackoff = Duration(minutes: 10);

  /// Creation order (oldest first); stable for equal timestamps.
  static List<OfflineOrder> inCreationOrder(Iterable<OfflineOrder> entries) {
    final list = entries.toList();
    list.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) return byTime;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
    return list;
  }

  /// Delay before the next automatic attempt after [retryCount] failures.
  static Duration backoff(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    final shift = retryCount - 1 > 10 ? 10 : retryCount - 1;
    final factor = 1 << shift;
    final delay = baseBackoff * factor;
    return delay > maxBackoff ? maxBackoff : delay;
  }

  static bool isDue(OfflineOrder e, DateTime now, {required bool manual}) {
    if (e.status != SyncStatus.pending) return false;
    if (manual) return true;
    if (e.retryCount >= maxAutoRetries) return false;
    final last = e.lastAttemptAt;
    if (last == null) return true;
    return !now.isBefore(last.add(backoff(e.retryCount)));
  }

  /// Entries to send now, in creation order. Only `pending` rows qualify.
  static List<OfflineOrder> dueForPush(
    Iterable<OfflineOrder> entries,
    DateTime now, {
    bool manual = false,
  }) =>
      inCreationOrder(entries.where((e) => isDue(e, now, manual: manual)))
          .toList();

  static OfflineOrder markSyncing(OfflineOrder e, DateTime now) =>
      e.copyWith(status: SyncStatus.syncing, lastAttemptAt: now);

  /// Applies the server's final answer.
  static OfflineOrder applyResult(
    OfflineOrder e,
    OrderSyncResult r,
    DateTime now, {
    required bool manual,
  }) {
    final mode = manual ? 'Thủ công - bạn bấm đồng bộ' : 'Tự động khi có mạng';
    if (r.accepted) {
      return e.copyWith(
        status: SyncStatus.synced,
        syncedAt: now,
        serverOrderCode: r.orderCode,
        error: '',
        syncMode: mode,
        finalAmount: r.finalAmount,
        promoChanged: r.promoChanged,
        changeReason: r.changeReason,
      );
    }
    return e.copyWith(
      status: SyncStatus.rejected,
      syncedAt: now,
      serverOrderCode: r.orderCode,
      error: r.reason.isEmpty ? 'Hệ thống từ chối đơn hàng.' : r.reason,
      syncMode: mode,
    );
  }

  /// Transient failure (offline, timeout, 5xx): back to `pending`.
  static OfflineOrder markFailed(OfflineOrder e, String error, DateTime now) =>
      e.copyWith(
        status: SyncStatus.pending,
        retryCount: e.retryCount + 1,
        error: error,
        lastAttemptAt: now,
      );

  /// Rows left `syncing` by a killed app go back to `pending`.
  static OfflineOrder recoverStale(OfflineOrder e) =>
      e.status == SyncStatus.syncing
          ? e.copyWith(status: SyncStatus.pending)
          : e;

  /// Counts used by the three tabs (Chưa / Đang / Đã đồng bộ).
  static Map<String, int> tabCounts(Iterable<OfflineOrder> entries) {
    var todo = 0;
    var doing = 0;
    var done = 0;
    for (final e in entries) {
      switch (e.status) {
        case SyncStatus.pending:
          todo++;
        case SyncStatus.syncing:
          doing++;
        case SyncStatus.synced:
        case SyncStatus.rejected:
          done++;
      }
    }
    return <String, int>{'todo': todo, 'doing': doing, 'done': done};
  }
}
