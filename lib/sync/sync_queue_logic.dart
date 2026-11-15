import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';

class SyncQueueLogic {
  SyncQueueLogic._();

  /// A crashed/interrupted send can be retried explicitly after this period.
  /// The same payload and idempotency key must be retained.
  static const Duration interruptedSendDelay = Duration(minutes: 2);

  static bool canEdit(OfflineOrder entry) =>
      entry.payload.pendingOnlineRequest == null &&
      (entry.status == SyncStatus.pending ||
          entry.status == SyncStatus.failed) &&
      entry.lastAttemptAt == null &&
      entry.retryCount == 0;

  static bool canSend(OfflineOrder entry, DateTime now) {
    if (entry.status == SyncStatus.pending ||
        entry.status == SyncStatus.failed) {
      return true;
    }

    if (entry.status != SyncStatus.syncing) {
      return false;
    }

    final attemptedAt = entry.lastAttemptAt;
    return attemptedAt != null &&
        !now.isBefore(attemptedAt.add(interruptedSendDelay));
  }

  static List<OfflineOrder> inCreationOrder(
    Iterable<OfflineOrder> entries,
  ) {
    final result = entries.toList();

    result.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      if (byTime != 0) {
        return byTime;
      }

      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    return result;
  }

  static OfflineOrder markFailed(
    OfflineOrder entry,
    String error,
    DateTime now,
  ) =>
      entry.copyWith(
        status: SyncStatus.failed,
        retryCount: entry.retryCount + 1,
        error: error,
        lastAttemptAt: now,
      );

  static Map<String, int> tabCounts(
    Iterable<OfflineOrder> entries,
  ) {
    var todo = 0;
    var doing = 0;
    var done = 0;

    for (final entry in entries) {
      switch (entry.status) {
        case SyncStatus.pending:
        case SyncStatus.failed:
        case SyncStatus.needsConfirmation:
          todo++;
        case SyncStatus.syncing:
          doing++;
        case SyncStatus.synced:
        case SyncStatus.rejected:
          done++;
      }
    }

    return <String, int>{
      'todo': todo,
      'doing': doing,
      'done': done,
    };
  }

  /// A generic 409 or a conflict belonging to a different draft is not consentable.
  static bool matchesConflict(
    OfflineOrderPayload payload,
    OfflineConditionConflict conflict,
  ) {
    if (payload.clientRequestId.toLowerCase() !=
            conflict.clientOrderKey.toLowerCase() ||
        payload.snapshotVersion != conflict.snapshotVersion ||
        payload.localFinal != conflict.offlineEstimatedAmount ||
        !payload.hasCompleteExpectedConditions) {
      return false;
    }
    for (final line in conflict.changedLines) {
      final expected = payload.expectedConditions.where(
        (item) => item.productId.toLowerCase() == line.productId.toLowerCase(),
      );
      if (expected.length != 1) {
        return false;
      }
      final item = expected.single;
      if (item.expectedBaseUnitPrice != line.expectedBaseUnitPrice ||
          item.expectedMlorVersion != line.expectedMlorVersion ||
          item.expectedMlorRatio != line.expectedMlorRatio) {
        return false;
      }
    }
    return true;
  }
}
