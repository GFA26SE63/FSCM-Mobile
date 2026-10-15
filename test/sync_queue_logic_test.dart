import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

OfflineOrder entry(
  int id,
  DateTime createdAt, {
  SyncStatus status = SyncStatus.pending,
  int retryCount = 0,
  DateTime? lastAttemptAt,
}) {
  final seq = id.toString().padLeft(4, '0');
  return OfflineOrder(
    id: id,
    clientRequestId: 'uuid-$id',
    status: status,
    createdAt: createdAt,
    retryCount: retryCount,
    lastAttemptAt: lastAttemptAt,
    payload: OfflineOrderPayload(
      clientRequestId: 'uuid-$id',
      offlineCode: 'OFF-TEST-$seq',
      retailerCode: '10004127',
      retailerName: 'Tạp hóa Minh Châu',
      createdAt: createdAt,
      payment: PaymentMethod.cod,
      creditTerm: 0,
      lines: const <CartLine>[CartLine(sku: 'SKU001', qty: 10)],
      localTotal: 1000000,
      localDiscount: 0,
    ),
  );
}

void main() {
  final t0 = DateTime(2026, 9, 27, 10, 0);

  group('creation order', () {
    test('oldest order is pushed first regardless of list order', () {
      final a = entry(1, t0);
      final b = entry(2, t0.add(const Duration(minutes: 5)));
      final c = entry(3, t0.add(const Duration(minutes: 9)));
      final sorted = SyncQueueLogic.inCreationOrder(<OfflineOrder>[c, a, b]);
      expect(sorted.map((e) => e.id), <int?>[1, 2, 3]);
    });

    test('equal timestamps fall back to the queue id', () {
      final x = entry(7, t0);
      final y = entry(5, t0);
      final sorted = SyncQueueLogic.inCreationOrder(<OfflineOrder>[x, y]);
      expect(sorted.map((e) => e.id), <int?>[5, 7]);
    });

    test('dueForPush keeps creation order and skips non-pending rows', () {
      final now = t0.add(const Duration(hours: 1));
      final list = <OfflineOrder>[
        entry(3, t0.add(const Duration(minutes: 3))),
        entry(1, t0, status: SyncStatus.synced),
        entry(2, t0.add(const Duration(minutes: 2))),
        entry(4, t0.add(const Duration(minutes: 4)),
            status: SyncStatus.rejected),
        entry(5, t0.add(const Duration(minutes: 5)),
            status: SyncStatus.syncing),
      ];
      final due = SyncQueueLogic.dueForPush(list, now);
      expect(due.map((e) => e.id), <int?>[2, 3]);
    });
  });

  group('backoff', () {
    test('doubles from 20s and is capped at 10 minutes', () {
      expect(SyncQueueLogic.backoff(0), Duration.zero);
      expect(SyncQueueLogic.backoff(1), const Duration(seconds: 20));
      expect(SyncQueueLogic.backoff(2), const Duration(seconds: 40));
      expect(SyncQueueLogic.backoff(3), const Duration(seconds: 80));
      expect(SyncQueueLogic.backoff(6), const Duration(minutes: 10));
      expect(SyncQueueLogic.backoff(40), const Duration(minutes: 10));
    });

    test('a failed entry waits for its backoff before the next automatic try',
        () {
      final failedAt = t0;
      final e = entry(1, t0, retryCount: 2, lastAttemptAt: failedAt);
      expect(
        SyncQueueLogic.isDue(e, failedAt.add(const Duration(seconds: 39)),
            manual: false),
        isFalse,
      );
      expect(
        SyncQueueLogic.isDue(e, failedAt.add(const Duration(seconds: 40)),
            manual: false),
        isTrue,
      );
    });

    test('automatic retries stop at the limit but manual sync still works', () {
      final e = entry(
        1,
        t0,
        retryCount: SyncQueueLogic.maxAutoRetries,
        lastAttemptAt: t0,
      );
      final later = t0.add(const Duration(days: 1));
      expect(SyncQueueLogic.isDue(e, later, manual: false), isFalse);
      expect(SyncQueueLogic.isDue(e, later, manual: true), isTrue);
    });
  });

  group('server result is final', () {
    test('accepted order becomes synced with the server code', () {
      final now = t0.add(const Duration(minutes: 30));
      const result = OrderSyncResult(
        clientRequestId: 'uuid-1',
        accepted: true,
        orderCode: 'DH-001031',
        finalAmount: 950000,
        promoChanged: true,
        changeReason: 'KM-003 đã tạm dừng',
      );
      final updated =
          SyncQueueLogic.applyResult(entry(1, t0), result, now, manual: false);
      expect(updated.status, SyncStatus.synced);
      expect(updated.serverOrderCode, 'DH-001031');
      expect(updated.finalAmount, 950000);
      expect(updated.promoChanged, isTrue);
      expect(updated.syncedAt, now);
      expect(updated.error, isEmpty);
    });

    test('rejected order keeps the reason and is never due again', () {
      final now = t0.add(const Duration(minutes: 30));
      const result = OrderSyncResult(
        clientRequestId: 'uuid-1',
        accepted: false,
        reason: 'Không đủ tồn kho SKU001',
      );
      final updated =
          SyncQueueLogic.applyResult(entry(1, t0), result, now, manual: true);
      expect(updated.status, SyncStatus.rejected);
      expect(updated.error, 'Không đủ tồn kho SKU001');
      expect(
        SyncQueueLogic.isDue(updated, now.add(const Duration(days: 1)),
            manual: true),
        isFalse,
      );
    });

    test('network failure goes back to pending and counts a retry', () {
      final now = t0.add(const Duration(minutes: 1));
      final syncing = SyncQueueLogic.markSyncing(entry(1, t0), now);
      expect(syncing.status, SyncStatus.syncing);
      final failed = SyncQueueLogic.markFailed(syncing, 'Mất kết nối', now);
      expect(failed.status, SyncStatus.pending);
      expect(failed.retryCount, 1);
      expect(failed.lastAttemptAt, now);
    });

    test('rows stuck in syncing after a crash are recovered to pending', () {
      final stuck = entry(1, t0, status: SyncStatus.syncing);
      expect(SyncQueueLogic.recoverStale(stuck).status, SyncStatus.pending);
      final done = entry(2, t0, status: SyncStatus.synced);
      expect(SyncQueueLogic.recoverStale(done).status, SyncStatus.synced);
    });
  });

  test('tabCounts groups rows like the three tabs', () {
    final counts = SyncQueueLogic.tabCounts(<OfflineOrder>[
      entry(1, t0),
      entry(2, t0),
      entry(3, t0, status: SyncStatus.syncing),
      entry(4, t0, status: SyncStatus.synced),
      entry(5, t0, status: SyncStatus.rejected),
    ]);
    expect(counts['todo'], 2);
    expect(counts['doing'], 1);
    expect(counts['done'], 2);
  });
}
