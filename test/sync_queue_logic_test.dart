import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

void main() {
  final createdAt = DateTime.utc(2026, 11, 8, 1);

  OfflineOrder draft({
    SyncStatus status = SyncStatus.pending,
    DateTime? attemptedAt,
    int retryCount = 0,
  }) =>
      OfflineOrder(
        clientRequestId: 'draft-key',
        payload: OfflineOrderPayload(
          clientRequestId: 'draft-key',
          offlineCode: 'OFF-TEST-0001',
          retailerId: 'retailer-id',
          retailerCode: 'RT001',
          retailerName: 'Retailer',
          createdAt: createdAt,
          lines: const <CartLine>[
            CartLine(
              productId: 'product-id',
              sku: 'SKU001',
              qty: 10,
            ),
          ],
          localTotal: 1000,
          localDiscount: 0,
        ),
        status: status,
        createdAt: createdAt,
        lastAttemptAt: attemptedAt,
        retryCount: retryCount,
      );

  test('only a never-attempted draft can be edited or deleted', () {
    expect(SyncQueueLogic.canEdit(draft()), isTrue);

    expect(
      SyncQueueLogic.canEdit(
        draft(attemptedAt: createdAt),
      ),
      isFalse,
    );

    expect(
      SyncQueueLogic.canEdit(
        draft(retryCount: 1),
      ),
      isFalse,
    );

    expect(
      SyncQueueLogic.canEdit(
        draft(status: SyncStatus.synced),
      ),
      isFalse,
    );
  });

  test('an interrupted send cannot immediately be claimed again', () {
    final sending = draft(
      status: SyncStatus.syncing,
      attemptedAt: createdAt,
    );

    expect(
      SyncQueueLogic.canSend(
        sending,
        createdAt.add(const Duration(seconds: 30)),
      ),
      isFalse,
    );

    expect(
      SyncQueueLogic.canSend(
        sending,
        createdAt.add(const Duration(minutes: 2)),
      ),
      isTrue,
    );
  });

  test('failure retains payload and key for explicit retry', () {
    final original = draft(
      status: SyncStatus.syncing,
      attemptedAt: createdAt,
    );

    final failed = SyncQueueLogic.markFailed(
      original,
      'Timeout',
      createdAt,
    );

    expect(failed.status, SyncStatus.failed);
    expect(failed.retryCount, 1);
    expect(failed.clientRequestId, original.clientRequestId);
    expect(failed.payload.toJson(), original.payload.toJson());
    expect(SyncQueueLogic.canEdit(failed), isFalse);
    expect(
      SyncQueueLogic.canSend(failed, createdAt),
      isTrue,
    );
  });
}
