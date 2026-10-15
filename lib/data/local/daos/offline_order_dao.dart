import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';

/// OfflineOrderQueue: orders created without network, waiting for
/// `POST /orders/sync`. The auto-increment `id` is the creation order.
class OfflineOrderDao {
  OfflineOrderDao(this._appDb);

  final AppDatabase _appDb;

  Future<void> insert(OfflineOrder order) async {
    final db = await _appDb.database;
    await db.insert(
      Tables.offlineOrderQueue,
      <String, Object?>{
        'client_request_id': order.clientRequestId,
        'offline_code': order.localCode,
        'payload': jsonEncode(order.payload.toJson()),
        'status': order.status.code,
        'retry_count': order.retryCount,
        'error': order.error,
        'created_at': AppDates.iso(order.createdAt),
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Persists status-related columns of [order] (payload is immutable).
  Future<void> update(OfflineOrder order) async {
    final db = await _appDb.database;
    await db.update(
      Tables.offlineOrderQueue,
      <String, Object?>{
        'status': order.status.code,
        'retry_count': order.retryCount,
        'error': order.error,
        'last_attempt_at': isoOrNull(order.lastAttemptAt),
        'synced_at': isoOrNull(order.syncedAt),
        'server_order_code': order.serverOrderCode,
        'sync_mode': order.syncMode,
        'final_amount': order.finalAmount,
        'promo_changed': order.promoChanged ? 1 : 0,
        'change_reason': order.changeReason,
      },
      where: 'client_request_id = ?',
      whereArgs: <Object?>[order.clientRequestId],
    );
  }

  /// All entries, newest first (queue screen).
  Future<List<OfflineOrder>> all() async {
    final db = await _appDb.database;
    final rows = await db.query(Tables.offlineOrderQueue, orderBy: 'id DESC');
    return rows.map(_fromRow).toList();
  }

  /// Entries in creation order (oldest first) for the given statuses.
  Future<List<OfflineOrder>> byStatus(List<SyncStatus> statuses) async {
    final db = await _appDb.database;
    final marks = List<String>.filled(statuses.length, '?').join(',');
    final rows = await db.query(
      Tables.offlineOrderQueue,
      where: 'status IN ($marks)',
      whereArgs: statuses.map((s) => s.code).toList(),
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<OfflineOrder?> byLocalCode(String code) async {
    final db = await _appDb.database;
    final rows = await db.query(
      Tables.offlineOrderQueue,
      where: 'offline_code = ? OR server_order_code = ?',
      whereArgs: <Object?>[code, code],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> delete(String clientRequestId) async {
    final db = await _appDb.database;
    await db.delete(
      Tables.offlineOrderQueue,
      where: 'client_request_id = ?',
      whereArgs: <Object?>[clientRequestId],
    );
  }

  Future<int> countByStatus(SyncStatus status) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.offlineOrderQueue} WHERE status = ?',
      <Object?>[status.code],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  OfflineOrder _fromRow(Map<String, Object?> r) => OfflineOrder(
        id: (r['id'] as num?)?.toInt(),
        clientRequestId: r['client_request_id']! as String,
        payload: OfflineOrderPayload.fromJson(
            asMap(jsonDecode(r['payload']! as String))),
        status: SyncStatus.fromCode(r['status'] as String?),
        createdAt: AppDates.tryParse(r['created_at']) ?? DateTime.now(),
        retryCount: (r['retry_count'] as num?)?.toInt() ?? 0,
        error: (r['error'] as String?) ?? '',
        lastAttemptAt: AppDates.tryParse(r['last_attempt_at']),
        syncedAt: AppDates.tryParse(r['synced_at']),
        serverOrderCode: (r['server_order_code'] as String?) ?? '',
        syncMode: (r['sync_mode'] as String?) ?? '',
        finalAmount: (r['final_amount'] as num?)?.toInt(),
        promoChanged: ((r['promo_changed'] as num?)?.toInt() ?? 0) == 1,
        changeReason: (r['change_reason'] as String?) ?? '',
      );
}
