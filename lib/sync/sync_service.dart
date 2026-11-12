import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/remote/sync_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/sync/draft_submission_failure.dart';

enum SyncPhase { idle, pushing, pulling }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.lastError,
    this.lastSummary,
  });

  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final String? lastError;
  final String? lastSummary;

  bool get busy => phase != SyncPhase.idle;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
    String? lastSummary,
    bool clearSummary = false,
  }) =>
      SyncState(
        phase: phase ?? this.phase,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearError ? null : lastError ?? this.lastError,
        lastSummary: clearSummary ? null : lastSummary ?? this.lastSummary,
      );
}

final syncServiceProvider =
    StateNotifierProvider<SyncService, SyncState>((ref) {
  final user = ref.watch(currentUserProvider);

  return SyncService(
    ref,
    ownerId: user?.id ?? '',
    isSales: user?.role == UserRole.sales,
  );
});

class SyncService extends StateNotifier<SyncState> {
  SyncService(
    this._ref, {
    required String ownerId,
    required bool isSales,
  })  : _ownerId = ownerId,
        _isSales = isSales,
        super(const SyncState()) {
    _ref.listen<NetworkState>(
      networkMonitorProvider,
      (previous, next) {
        if (!(previous?.online ?? false) && next.online) {
          // Reconnection downloads catalog only.
          unawaited(refreshSnapshot());
        }
      },
    );
  }

  final Ref _ref;
  final String _ownerId;
  final bool _isSales;

  bool _running = false;

  bool get _sessionMatches =>
      mounted &&
      _ownerId.isNotEmpty &&
      _ref.read(currentUserProvider)?.id == _ownerId;

  bool get _online => _ref.read(networkMonitorProvider).online;

  void _bump() {
    if (_sessionMatches) {
      _ref.read(dataVersionProvider.notifier).state++;
    }
  }

  Future<void> refreshSnapshot() async {
    if (_running || !_sessionMatches || !_online) {
      return;
    }

    final api = _ref.read(syncApiProvider);
    final catalog = _ref.read(catalogRepositoryProvider);

    _running = true;
    state = state.copyWith(
      phase: SyncPhase.pulling,
      clearError: true,
      clearSummary: true,
    );

    try {
      final snapshot = await api.snapshot();

      if (!_sessionMatches) {
        return;
      }

      await catalog.applySnapshot(snapshot);

      if (_sessionMatches) {
        state = state.copyWith(
          lastSyncAt: snapshot.serverTime,
          lastSummary: 'Đã cập nhật dữ liệu trên máy.',
        );
      }
    } catch (error) {
      if (_sessionMatches) {
        state = state.copyWith(
          lastError: ApiException.describe(error),
        );
      }
    } finally {
      _running = false;

      if (mounted) {
        state = state.copyWith(phase: SyncPhase.idle);
      }

      _bump();
    }
  }

  /// Only explicit user actions call this method.
  Future<bool> sendDraft(
    String clientRequestId, {
    OfflineConditionConflict? confirmedConditions,
  }) async {
    if (_running || !_sessionMatches || !_isSales) {
      return false;
    }

    if (!_online) {
      state = state.copyWith(
        lastError: 'Đang offline. Draft được giữ trên máy.',
        clearSummary: true,
      );
      return false;
    }

    final queue = _ref.read(offlineOrderDaoProvider);
    final api = _ref.read(ordersApiProvider);

    _running = true;
    state = state.copyWith(
      phase: SyncPhase.pushing,
      clearError: true,
      clearSummary: true,
    );

    OfflineOrder? sending;

    try {
      sending = await queue.claimForSend(
        clientRequestId,
        ownerId: _ownerId,
        now: AppClock.now(),
        confirmedConditions: confirmedConditions,
      );

      _bump();

      if (!_sessionMatches) {
        throw const ApiException(
          kind: ApiErrorKind.unauthorized,
          message: 'Phiên đăng nhập đã thay đổi trước khi gửi.',
        );
      }

      final result = await api.submitOffline(
        sending.payload,
        confirmConditionChanges: sending.conditionsConfirmed,
      );

      if (result.clientRequestId != sending.clientRequestId) {
        throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Máy chủ chưa trả kết quả hợp lệ. Có thể gửi lại.',
        );
      }

      if (!result.accepted) {
        throw ApiException(
          kind: ApiErrorKind.validation,
          message: result.reason.isEmpty
              ? 'Máy chủ chưa chấp nhận draft.'
              : result.reason,
        );
      }

      if (result.orderCode.isEmpty) {
        throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Chưa nhận được mã đơn server. Giữ draft để gửi lại.',
        );
      }

      final saved = await queue.finishAttempt(
        sending.copyWith(
          status: SyncStatus.synced,
          syncedAt: AppClock.now(),
          serverOrderCode: result.orderCode,
          error: '',
          syncMode: 'Sales bấm Gửi',
          finalAmount: result.finalAmount,
          serverOrder: result.serverOrder,
          promoChanged: result.promoChanged,
          changeReason: result.changeReason,
        ),
        ownerId: _ownerId,
        attemptedAt: sending.lastAttemptAt!,
      );

      if (_sessionMatches) {
        state = state.copyWith(
          lastSummary: saved
              ? 'Đã gửi ${sending.localCode} → ${result.orderCode}.'
              : 'Lần gửi này đã được thay thế. Hãy tải lại draft.',
        );
      }

      return saved;
    } catch (error) {
      var message = ApiException.describe(error);

      final attempted = sending;
      final failure = attempted == null
          ? null
          : DraftSubmissionFailure.apply(attempted, error);
      var failureSaved = false;

      if (attempted != null) {
        try {
          failureSaved = await queue.finishAttempt(
            failure!,
            ownerId: _ownerId,
            attemptedAt: attempted.lastAttemptAt!,
          );
        } catch (storageError) {
          message = '$message\n'
              'Chưa lưu được kết quả gửi: '
              '${ApiException.describe(storageError)}';
        }
      } else if (error is ApiException &&
          error.kind == ApiErrorKind.validation) {
        try {
          await queue.recordPreparationFailure(
            clientRequestId,
            ownerId: _ownerId,
            message: message,
          );
        } catch (storageError) {
          message = '$message\n${ApiException.describe(storageError)}';
        }
      }

      if (_sessionMatches) {
        final waiting =
            failureSaved && failure?.status == SyncStatus.needsConfirmation;
        state = state.copyWith(
          lastError: waiting ? null : message,
          clearError: waiting,
          lastSummary: waiting
              ? 'Điều kiện đã thay đổi. Mở đối chiếu để xác nhận.'
              : null,
        );
      }

      return false;
    } finally {
      _running = false;

      if (mounted) {
        state = state.copyWith(phase: SyncPhase.idle);
      }

      _bump();
    }
  }
}
