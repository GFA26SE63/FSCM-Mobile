import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

import 'fixtures/offline_submission_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'reconnection never submits; explicit confirmation sends and refreshes list version',
      () async {
    final databaseName =
        'fscm_send_service_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = AppDatabase(databaseName: databaseName);
    final dao = OfflineOrderDao(database);
    final transport = _Transport();
    final client =
        ApiClient(transport: transport, tokenReader: () => 'test-token');
    final connectivity = _Connectivity();
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(const AppUser(
        id: 'sales-a',
        fullName: 'Sales',
        phone: '',
        role: UserRole.sales,
      )),
      appDatabaseProvider.overrideWithValue(database),
      apiClientProvider.overrideWithValue(client),
      networkMonitorProvider
          .overrideWith((ref) => NetworkMonitor(connectivity: connectivity)),
    ]);
    addTearDown(() async {
      container.dispose();
      client.dispose();
      await connectivity.events.close();
      await database.close();
      await deleteDatabase(p.join(await getDatabasesPath(), databaseName));
    });
    final draft = submissionDraft();
    await dao.insert(draft, ownerId: 'sales-a');
    final service = container.read(syncServiceProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    connectivity.events.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    await service.refreshSnapshot();
    expect(transport.submissions, isEmpty);
    expect((await dao.byId(draft.clientRequestId, ownerId: 'sales-a'))!.status,
        SyncStatus.pending);

    expect(await service.sendDraft(draft.clientRequestId), isFalse);
    final waiting =
        (await dao.byId(draft.clientRequestId, ownerId: 'sales-a'))!;
    expect(waiting.status, SyncStatus.needsConfirmation);
    final versionBeforeConfirmation = container.read(dataVersionProvider);
    expect(
        await service.sendDraft(draft.clientRequestId,
            confirmedConditions: waiting.conditionConflict),
        isTrue);

    final sent = (await dao.byId(draft.clientRequestId, ownerId: 'sales-a'))!;
    expect(sent.status, SyncStatus.synced);
    expect(sent.serverOrderCode, 'SO-NEW');
    expect(sent.serverOrder, isNotNull);
    expect(container.read(dataVersionProvider),
        greaterThan(versionBeforeConfirmation));
    expect(transport.submissions.length, 2);
    final first =
        Map<String, dynamic>.from(transport.submissions.first.body! as Map);
    final confirmed =
        Map<String, dynamic>.from(transport.submissions.last.body! as Map);
    expect(first.remove('confirmConditionChanges'), isFalse);
    expect(confirmed.remove('confirmConditionChanges'), isTrue);
    expect(confirmed, first);
  });
}

class _Connectivity implements Connectivity {
  final events = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.none];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => events.stream;
}

class _Transport implements ApiTransport {
  final submissions = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.method != 'POST' || request.path != Endpoints.ordersSync) {
      // Catalog download is independent of draft submission in this test.
      return const ApiResponse(statusCode: 503);
    }
    submissions.add(request);
    if (submissions.length == 1) {
      return ApiResponse(statusCode: 409, data: {
        'code': 'conflict',
        'details': submissionConflictJson(),
      });
    }
    return const ApiResponse(statusCode: 201, data: {
      'orderCode': 'SO-NEW',
      'source': 'Offline',
      'status': 'Allocating',
      'finalAmount': 1100,
    });
  }
}
