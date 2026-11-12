import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

/// Classifies a submission result without treating every HTTP 409 as consent.
class DraftSubmissionFailure {
  DraftSubmissionFailure._();

  static OfflineOrder apply(OfflineOrder sending, Object error) {
    final message = ApiException.describe(error);
    if (error is ApiException && error.statusCode == 409) {
      final conflict = OfflineConditionConflict.tryParse(
        error.problemDetails?['details'],
      );
      if (conflict != null &&
          SyncQueueLogic.matchesConflict(sending.payload, conflict)) {
        return sending.copyWith(
          status: SyncStatus.needsConfirmation,
          error: message,
          conditionConflict: conflict,
          conditionsConfirmed: false,
        );
      }
    }

    // Authentication, networking and generic conflicts remain retryable.
    final rejected = error is ApiException &&
        (error.kind == ApiErrorKind.validation ||
            error.kind == ApiErrorKind.notFound);
    return sending.copyWith(
      status: rejected ? SyncStatus.rejected : SyncStatus.failed,
      retryCount: sending.retryCount + 1,
      error: message,
    );
  }
}
