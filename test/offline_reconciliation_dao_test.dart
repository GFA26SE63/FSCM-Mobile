import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/sync/draft_submission_failure.dart';

import 'fixtures/offline_submission_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late OfflineOrderDao dao;
  late String databaseName;

  setUp(() async {
    databaseName =
        'fscm_reconciliation_${DateTime.now().microsecondsSinceEpoch}.db';
    database = AppDatabase(databaseName: databaseName);
    dao = OfflineOrderDao(database);
    await dao.insert(submissionDraft(), ownerId: 'sales-a');
  });

  tearDown(() async {
    await database.close();
    await deleteDatabase(p.join(await getDatabasesPath(), databaseName));
  });

  Future<OfflineOrder> requireConfirmation() async {
    final draft = submissionDraft();
    final sending = await dao.claimForSend(
      draft.clientRequestId,
      ownerId: 'sales-a',
      now: draft.createdAt,
    );
    final next = DraftSubmissionFailure.apply(
        sending,
        ApiException.fromProblem(409, {
          'code': 'conflict',
          'details': submissionConflictJson(),
        }));
    expect(
        await dao.finishAttempt(next,
            ownerId: 'sales-a', attemptedAt: sending.lastAttemptAt!),
        isTrue);
    return next;
  }

  test(
      'confirmation survives restart and cannot be bypassed or accepted from another account',
      () async {
    final waiting = await requireConfirmation();
    await database.close();
    final restored =
        (await dao.byId(waiting.clientRequestId, ownerId: 'sales-a'))!;
    expect(restored.status, SyncStatus.needsConfirmation);
    expect(
        restored.conditionConflict!.sameAs(waiting.conditionConflict!), isTrue);
    expect(restored.conditionsConfirmed, isFalse);
    await expectLater(
        dao.claimForSend(restored.clientRequestId,
            ownerId: 'sales-a',
            now: restored.createdAt.add(const Duration(minutes: 3))),
        throwsA(isA<ApiException>()));
    await expectLater(
        dao.claimForSend(restored.clientRequestId,
            ownerId: 'sales-b',
            now: restored.createdAt.add(const Duration(minutes: 3)),
            confirmedConditions: restored.conditionConflict),
        throwsA(isA<ApiException>()));
  });

  test(
      'stale confirmation is rejected; timeout retains original request and explicit consent',
      () async {
    final waiting = await requireConfirmation();
    final stale = OfflineConditionConflict.tryParse({
      ...waiting.conditionConflict!.toJson(),
      'currentIndicativeAmount': 1200,
    })!;
    final at = waiting.createdAt.add(const Duration(seconds: 1));
    await expectLater(
        dao.claimForSend(waiting.clientRequestId,
            ownerId: 'sales-a', now: at, confirmedConditions: stale),
        throwsA(isA<ApiException>()));

    final confirmed = await dao.claimForSend(waiting.clientRequestId,
        ownerId: 'sales-a',
        now: at,
        confirmedConditions: waiting.conditionConflict);
    expect(confirmed.conditionsConfirmed, isTrue);
    final failed =
        DraftSubmissionFailure.apply(confirmed, const ApiException.timeout());
    await dao.finishAttempt(failed, ownerId: 'sales-a', attemptedAt: at);
    await database.close();
    final retry = await dao.claimForSend(waiting.clientRequestId,
        ownerId: 'sales-a', now: at.add(const Duration(seconds: 1)));
    expect(retry.conditionsConfirmed, isTrue);
    expect(
        retry.payload
            .toRequestJson(confirmConditionChanges: retry.conditionsConfirmed),
        confirmed.payload.toRequestJson(confirmConditionChanges: true));

    final changedAgain = DraftSubmissionFailure.apply(
        retry,
        ApiException.fromProblem(409, {
          'details': {
            ...submissionConflictJson(),
            'currentIndicativeAmount': 1200
          },
        }));
    await dao.finishAttempt(changedAgain,
        ownerId: 'sales-a', attemptedAt: retry.lastAttemptAt!);
    final updated =
        (await dao.byId(waiting.clientRequestId, ownerId: 'sales-a'))!;
    expect(updated.conditionsConfirmed, isFalse);
    expect(updated.status, SyncStatus.needsConfirmation);
    expect(updated.conditionConflict!.currentIndicativeAmount, 1200);
  });

  test(
      'sent receipt preserves both order codes and server amounts after restart',
      () async {
    final draft = submissionDraft();
    final sending = await dao.claimForSend(draft.clientRequestId,
        ownerId: 'sales-a', now: draft.createdAt);
    final receipt = Order.fromJson({
      'orderCode': 'SO-NEW',
      'source': 'Offline',
      'status': 'Quoted',
      'retailerCode': 'RT001',
      'retailerName': 'Retailer',
      'subtotalAmount': 1200,
      'discountAmount': 100,
      'createdAt': draft.createdAt.toIso8601String(),
    });
    await dao.finishAttempt(
        sending.copyWith(
            status: SyncStatus.synced,
            serverOrderCode: 'SO-NEW',
            serverOrder: receipt,
            finalAmount: 1100,
            syncedAt: draft.createdAt),
        ownerId: 'sales-a',
        attemptedAt: draft.createdAt);
    await database.close();
    final entry = (await dao.byId(draft.clientRequestId, ownerId: 'sales-a'))!;
    final order = orderFromOffline(entry);
    expect(entry.finalAmount, 1100);
    expect(order.code, 'SO-NEW');
    expect(order.offlineCode, draft.localCode);
    expect(order.status, OrderStatus.quoted);
    expect(order.finalAmount, 1100);
    expect(order.localFinal, 1000);
    expect(order.syncStatus, SyncStatus.synced);
  });
}
