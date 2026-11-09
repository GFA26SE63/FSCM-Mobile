import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_expected_condition.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late OfflineOrderDao dao;
  late String databaseName;

  final createdAt = DateTime.utc(2026, 11, 8, 1);

  OfflineOrderPayload payload({int quantity = 10}) => OfflineOrderPayload(
        clientRequestId: '11111111-1111-4111-8111-111111111111',
        offlineCode: 'OFF-TEST-0001',
        retailerId: '22222222-2222-4222-8222-222222222222',
        retailerCode: 'RT001',
        retailerName: 'Retailer',
        createdAt: createdAt,
        lines: <CartLine>[
          CartLine(
            productId: '33333333-3333-4333-8333-333333333333',
            sku: 'SKU001',
            qty: quantity,
          ),
        ],
        localTotal: quantity * 100,
        localDiscount: 0,
        snapshotVersion: 'snapshot-1',
        expectedConditions: const <OfflineExpectedCondition>[
          OfflineExpectedCondition(
            productId: '33333333-3333-4333-8333-333333333333',
            expectedBaseUnitPrice: 100,
            expectedMlorVersion: 1,
            expectedMlorRatio: 0.5,
          ),
        ],
      );

  OfflineOrder draft() {
    final value = payload();

    return OfflineOrder(
      clientRequestId: value.clientRequestId,
      payload: value,
      status: SyncStatus.pending,
      createdAt: createdAt,
    );
  }

  setUp(() async {
    databaseName =
        'fscm_draft_test_${DateTime.now().microsecondsSinceEpoch}.db';
    database = AppDatabase(databaseName: databaseName);
    dao = OfflineOrderDao(database);
  });

  tearDown(() async {
    await database.close();
    await deleteDatabase(
      p.join(await getDatabasesPath(), databaseName),
    );
  });

  test('another account cannot read or claim a draft', () async {
    final entry = draft();
    await dao.insert(entry, ownerId: 'sales-a');

    expect(await dao.all(ownerId: 'sales-b'), isEmpty);

    await expectLater(
      dao.claimForSend(
        entry.clientRequestId,
        ownerId: 'sales-b',
        now: createdAt,
      ),
      throwsA(isA<ApiException>()),
    );

    final original = await dao.byId(
      entry.clientRequestId,
      ownerId: 'sales-a',
    );

    expect(original?.status, SyncStatus.pending);
  });

  test('editing a draft preserves its persistent key and local code', () async {
    final entry = draft();
    await dao.insert(entry, ownerId: 'sales-a');

    await dao.replaceDraft(
      ownerId: 'sales-a',
      original: entry,
      replacement: payload(quantity: 20),
    );

    final updated = await dao.byId(
      entry.clientRequestId,
      ownerId: 'sales-a',
    );

    expect(updated!.clientRequestId, entry.clientRequestId);
    expect(updated.localCode, entry.localCode);
    expect(updated.payload.lines.single.qty, 20);
    expect(updated.lastAttemptAt, isNull);

    await expectLater(
      dao.replaceDraft(
        ownerId: 'sales-a',
        original: entry,
        replacement: payload(quantity: 30),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('a claimed draft cannot be edited or deleted', () async {
    final entry = draft();
    await dao.insert(entry, ownerId: 'sales-a');

    await dao.claimForSend(
      entry.clientRequestId,
      ownerId: 'sales-a',
      now: createdAt,
    );

    await expectLater(
      dao.replaceDraft(
        ownerId: 'sales-a',
        original: entry,
        replacement: payload(quantity: 20),
      ),
      throwsA(isA<ApiException>()),
    );

    await expectLater(
      dao.deleteDraft(
        entry.clientRequestId,
        ownerId: 'sales-a',
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('failed submission retries with the same request body', () async {
    final entry = draft();
    await dao.insert(entry, ownerId: 'sales-a');

    final first = await dao.claimForSend(
      entry.clientRequestId,
      ownerId: 'sales-a',
      now: createdAt,
    );

    await dao.finishAttempt(
      SyncQueueLogic.markFailed(first, 'Timeout', createdAt),
      ownerId: 'sales-a',
      attemptedAt: createdAt,
    );

    final retry = await dao.claimForSend(
      entry.clientRequestId,
      ownerId: 'sales-a',
      now: createdAt.add(const Duration(seconds: 1)),
    );

    expect(
      retry.payload.toRequestJson(),
      first.payload.toRequestJson(),
    );
    expect(retry.retryCount, 1);
    expect(retry.payload.toRequestJson()['confirmConditionChanges'], isFalse);
  });

  test('late result cannot overwrite a newer send attempt', () async {
    final entry = draft();
    await dao.insert(entry, ownerId: 'sales-a');

    final first = await dao.claimForSend(
      entry.clientRequestId,
      ownerId: 'sales-a',
      now: createdAt,
    );

    final later = createdAt.add(const Duration(minutes: 3));

    final second = await dao.claimForSend(
      entry.clientRequestId,
      ownerId: 'sales-a',
      now: later,
    );

    final oldSaved = await dao.finishAttempt(
      first.copyWith(
        status: SyncStatus.synced,
        serverOrderCode: 'SO-OLD',
      ),
      ownerId: 'sales-a',
      attemptedAt: createdAt,
    );

    expect(oldSaved, isFalse);

    final newSaved = await dao.finishAttempt(
      second.copyWith(
        status: SyncStatus.synced,
        serverOrderCode: 'SO-NEW',
      ),
      ownerId: 'sales-a',
      attemptedAt: later,
    );

    expect(newSaved, isTrue);

    final result = await dao.byId(
      entry.clientRequestId,
      ownerId: 'sales-a',
    );

    expect(result!.serverOrderCode, 'SO-NEW');
  });

  test('deleting an untouched draft affects only that draft', () async {
    final entry = draft();
    await dao.insert(entry, ownerId: 'sales-a');

    await dao.deleteDraft(
      entry.clientRequestId,
      ownerId: 'sales-a',
    );

    expect(await dao.all(ownerId: 'sales-a'), isEmpty);
  });
}
