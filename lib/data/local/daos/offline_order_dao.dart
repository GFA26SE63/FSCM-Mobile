import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

class OfflineOrderDao {
  OfflineOrderDao(this._appDb);

  final AppDatabase _appDb;

  static String _stamp(DateTime value) => value.toUtc().toIso8601String();

  static void _requireOwner(String ownerId) {
    if (ownerId.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Cần đăng nhập để truy cập bản nháp.',
      );
    }
  }

  Future<void> insert(
    OfflineOrder order, {
    required String ownerId,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;

    await db.insert(
      Tables.offlineOrderQueue,
      <String, Object?>{
        'owner_user_id': ownerId,
        'client_request_id': order.clientRequestId,
        'offline_code': order.localCode,
        'payload': jsonEncode(order.payload.toJson()),
        'status': order.status.code,
        'retry_count': order.retryCount,
        'error': order.error,
        'created_at': _stamp(order.createdAt),
        'last_attempt_at':
            order.lastAttemptAt == null ? null : _stamp(order.lastAttemptAt!),
        'synced_at': order.syncedAt == null ? null : _stamp(order.syncedAt!),
        'server_order_code': order.serverOrderCode,
        'sync_mode': order.syncMode,
        'final_amount': order.finalAmount,
        'promo_changed': order.promoChanged ? 1 : 0,
        'change_reason': order.changeReason,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<OfflineOrder>> all({
    required String ownerId,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;
    final rows = await db.query(
      Tables.offlineOrderQueue,
      where: 'owner_user_id = ?',
      whereArgs: <Object?>[ownerId],
      orderBy: 'id DESC',
    );

    return rows.map(_fromRow).toList();
  }

  Future<OfflineOrder?> byId(
    String clientRequestId, {
    required String ownerId,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;
    return _find(db, clientRequestId, ownerId);
  }

  Future<OfflineOrder?> byLocalCode(
    String code, {
    required String ownerId,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;
    final rows = await db.query(
      Tables.offlineOrderQueue,
      where:
          'owner_user_id = ? AND (offline_code = ? OR server_order_code = ?)',
      whereArgs: <Object?>[ownerId, code, code],
      limit: 1,
    );

    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Edits only a draft that has never started a network submission.
  /// The original JSON is checked to reject stale editors.
  Future<void> replaceDraft({
    required String ownerId,
    required OfflineOrder original,
    required OfflineOrderPayload replacement,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;

    await db.transaction((txn) async {
      final current = await _find(
        txn,
        original.clientRequestId,
        ownerId,
      );

      if (current == null) {
        throw const ApiException.notFoundLocal();
      }

      if (!SyncQueueLogic.canEdit(current)) {
        throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Draft đã bắt đầu gửi nên không thể sửa nội dung.',
        );
      }

      // Normalize the original through the same parser used by SQLite reads.
      // For example, an integer price of 100 becomes a double of 100.0.
      final normalizedOriginal = OfflineOrderPayload.fromJson(
        original.payload.toJson(),
      );

      if (jsonEncode(current.payload.toJson()) !=
          jsonEncode(normalizedOriginal.toJson())) {
        throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Draft đã thay đổi. Hãy đóng màn sửa và mở lại.',
        );
      }

      if (replacement.clientRequestId != current.clientRequestId ||
          replacement.offlineCode != current.localCode ||
          replacement.retailerId != current.payload.retailerId ||
          !replacement.createdAt.isAtSameMomentAs(current.payload.createdAt)) {
        throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Không được thay định danh hoặc điểm bán của draft.',
        );
      }

      replacement.toRequestJson();

      await txn.update(
        Tables.offlineOrderQueue,
        <String, Object?>{
          'payload': jsonEncode(replacement.toJson()),
          'error': '',
        },
        where: 'owner_user_id = ? AND client_request_id = ?',
        whereArgs: <Object?>[
          ownerId,
          current.clientRequestId,
        ],
      );
    });
  }

  Future<void> deleteDraft(
    String clientRequestId, {
    required String ownerId,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;

    await db.transaction((txn) async {
      final current = await _find(txn, clientRequestId, ownerId);

      if (current == null) {
        throw const ApiException.notFoundLocal();
      }

      if (!SyncQueueLogic.canEdit(current)) {
        throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Draft đã bắt đầu gửi. Giữ lại để đối chiếu hoặc gửi lại.',
        );
      }

      await txn.delete(
        Tables.offlineOrderQueue,
        where: 'owner_user_id = ? AND client_request_id = ?',
        whereArgs: <Object?>[ownerId, clientRequestId],
      );
    });
  }

  /// Atomically reads the latest payload and marks that exact draft sending.
  Future<OfflineOrder> claimForSend(
    String clientRequestId, {
    required String ownerId,
    required DateTime now,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;

    return db.transaction((txn) async {
      final current = await _find(txn, clientRequestId, ownerId);

      if (current == null) {
        throw const ApiException.notFoundLocal();
      }

      if (!SyncQueueLogic.canSend(current, now)) {
        throw const ApiException(
          kind: ApiErrorKind.conflict,
          message: 'Draft đang gửi hoặc đã có kết quả. Hãy tải lại.',
        );
      }

      // Validate before recording an actual send attempt.
      current.payload.toRequestJson();

      final sending = current.copyWith(
        status: SyncStatus.syncing,
        lastAttemptAt: now,
        error: '',
        syncMode: 'Sales bấm Gửi',
      );

      await txn.update(
        Tables.offlineOrderQueue,
        <String, Object?>{
          'status': sending.status.code,
          'last_attempt_at': _stamp(now),
          'error': '',
          'sync_mode': sending.syncMode,
        },
        where: 'owner_user_id = ? AND client_request_id = ?',
        whereArgs: <Object?>[ownerId, clientRequestId],
      );

      return sending;
    });
  }

  /// A late response from an older attempt cannot overwrite a newer attempt.
  Future<bool> finishAttempt(
    OfflineOrder result, {
    required String ownerId,
    required DateTime attemptedAt,
  }) async {
    _requireOwner(ownerId);

    final db = await _appDb.database;
    final changed = await db.update(
      Tables.offlineOrderQueue,
      <String, Object?>{
        'status': result.status.code,
        'retry_count': result.retryCount,
        'error': result.error,
        'synced_at': result.syncedAt == null ? null : _stamp(result.syncedAt!),
        'server_order_code': result.serverOrderCode,
        'sync_mode': result.syncMode,
        'final_amount': result.finalAmount,
        'promo_changed': result.promoChanged ? 1 : 0,
        'change_reason': result.changeReason,
      },
      where: '''
owner_user_id = ?
AND client_request_id = ?
AND status = ?
AND last_attempt_at = ?
''',
      whereArgs: <Object?>[
        ownerId,
        result.clientRequestId,
        SyncStatus.syncing.code,
        _stamp(attemptedAt),
      ],
    );

    return changed == 1;
  }

  Future<OfflineOrder?> _find(
    DatabaseExecutor db,
    String clientRequestId,
    String ownerId,
  ) async {
    final rows = await db.query(
      Tables.offlineOrderQueue,
      where: 'owner_user_id = ? AND client_request_id = ?',
      whereArgs: <Object?>[ownerId, clientRequestId],
      limit: 1,
    );

    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  OfflineOrder _fromRow(Map<String, Object?> row) {
    final payload = asMap(
      jsonDecode(row['payload']! as String),
    );

    payload.putIfAbsent(
      'clientRequestId',
      () => row['client_request_id'],
    );
    payload.putIfAbsent('offlineCode', () => row['offline_code']);
    payload.putIfAbsent('createdAt', () => row['created_at']);

    return OfflineOrder(
      id: (row['id'] as num?)?.toInt(),
      clientRequestId: row['client_request_id']! as String,
      payload: OfflineOrderPayload.fromJson(payload),
      status: SyncStatus.fromCode(row['status'] as String?),
      createdAt: AppDates.tryParse(row['created_at']) ?? DateTime.now(),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      error: row['error'] as String? ?? '',
      lastAttemptAt: AppDates.tryParse(row['last_attempt_at']),
      syncedAt: AppDates.tryParse(row['synced_at']),
      serverOrderCode: row['server_order_code'] as String? ?? '',
      syncMode: row['sync_mode'] as String? ?? '',
      finalAmount: (row['final_amount'] as num?)?.toInt(),
      promoChanged: (row['promo_changed'] as num?)?.toInt() == 1,
      changeReason: row['change_reason'] as String? ?? '',
    );
  }
}
