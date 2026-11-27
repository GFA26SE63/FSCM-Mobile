import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/sales_orders_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _statusesRejected = <String>[
  'QuoteRejected',
  'Withdrawn',
  'AllocationFailed',
];

/// Order `i` (0 = newest) has status `statusOf(i)` and is created `i` minutes
/// before [newest]. Answers `Orders`, `OrderCounts` and `OwnOrdersCreated`
/// like the Backend: the list filter refuses statuses outside its set.
class _Server implements ApiTransport {
  _Server(this.total, this.statusOf,
      {DateTime? newest, this.step = const Duration(minutes: 1)})
      : newest = newest ?? DateTime.utc(2026, 11, 1);

  /// Time between two consecutive orders.
  final Duration step;

  final int total;
  final String Function(int i) statusOf;
  final DateTime newest;
  final List<Map<String, dynamic>> orderRequests = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> aggregateRequests = <Map<String, dynamic>>[];
  bool failAggregate = false;
  bool offline = false;
  int created = 0, rejected = 0;
  bool Function(Map<String, dynamic> vars)? failOnce;

  Map<String, dynamic> row(int i) => <String, dynamic>{
        'id': 'id-$i',
        'orderCode': 'DH-$i',
        'retailerCode': 'RT1',
        'retailerName': 'Retailer',
        'status': statusOf(i),
        'finalAmount': 1000,
        'source': 'Online',
        'createdAt': newest.subtract(step * i).toIso8601String(),
      };

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final body = request.body! as Map<String, dynamic>;
    final vars = (body['variables'] as Map<String, dynamic>?) ?? {};
    if (offline) throw const ApiException.network();
    final operation = body['operationName'] as String;

    if (operation == 'OwnOrdersCreated') {
      aggregateRequests.add(vars);
      if (failAggregate) {
        throw const ApiException(
            kind: ApiErrorKind.validation, message: 'schema');
      }
      final n = vars.containsKey('st') ? rejected : created;
      return _entities(<String, dynamic>{
        'n': <String, dynamic>{'totalCount': n},
      });
    }
    if (operation == 'OrderCounts') {
      return _entities(<String, dynamic>{
        for (final key in vars.keys.where((k) => k.startsWith('s')))
          'c${key.substring(1)}': <String, dynamic>{'totalCount': 3},
      });
    }

    orderRequests.add(vars);
    if (failOnce != null && failOnce!(vars)) {
      failOnce = null;
      throw const ApiException(kind: ApiErrorKind.server, message: 'boom');
    }
    final status = vars['status'] as String?;
    if (status != null && !OrdersApi.listFilterStatuses.contains(status)) {
      throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Order status filter is invalid.');
    }
    final search = (vars['search'] as String?)?.toLowerCase();
    final matching = <int>[
      for (var i = 0; i < total; i++)
        if ((status == null || statusOf(i) == status) &&
            (search == null || 'dh-$i'.contains(search)))
          i
    ];
    final page = vars['page'] as int;
    final size = vars['pageSize'] as int;
    final slice = matching.skip((page - 1) * size).take(size);
    return _entities(<String, dynamic>{
      'orderReads': <String, dynamic>{
        'items': slice.map(row).toList(),
        'page': page,
        'pageSize': size,
        'totalCount': matching.length,
      },
    });
  }

  ApiResponse _entities(Map<String, dynamic> entities) =>
      ApiResponse(statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{'entities': entities},
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late OfflineOrderDao queue;
  late OrderRepository repository;
  late OrdersApi api;
  final controllers = <SalesOrdersController>[];

  Future<void> setUpRepository(_Server server) async {
    SharedPreferences.setMockInitialValues({'device_code': 'TEST'});
    final name = 'groups_${DateTime.now().microsecondsSinceEpoch}.db';
    database = AppDatabase(databaseName: name);
    queue = OfflineOrderDao(database);
    final client = ApiClient(transport: server, tokenReader: () => 'token');
    api = OrdersApi(client);
    repository = OrderRepository(
      api: api,
      queue: queue,
      syncState: SyncStateDao(database),
      device: DeviceIdentity(await SharedPreferences.getInstance()),
      ownerId: 'sales',
      isSales: true,
      isCurrentUser: () => true,
    );
    addTearDown(() async {
      for (final c in controllers) {
        c.dispose();
      }
      controllers.clear();
      client.dispose();
      await database.close();
      await deleteDatabase(p.join(await getDatabasesPath(), name));
    });
  }

  SalesOrdersController controller(SalesOrderGroup group,
      {String search = ''}) {
    final c = SalesOrdersController(repository,
        search: search, group: group, isCurrentUser: () => true);
    controllers.add(c);
    return c;
  }

  Future<SalesOrdersState> settle(SalesOrdersController c) async {
    for (var i = 0; i < 2000 && c.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c.state.value!;
  }

  Future<void> idle(SalesOrdersController c) async {
    // Let a running scan finish.
    for (var i = 0; i < 2000; i++) {
      final s = c.state.value;
      if (s != null && !s.loadingMore && !s.scanning) return;
      if (s != null && s.moreError != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> pendingOrder() => repository.createOffline(
        orderStep: 1,
        retailer: Retailer.fromJson({
          'id': 'retailer-id',
          'code': 'RT001',
          'name': 'T',
          'address': 'A'
        }),
        lines: const [CartLine(productId: 'p', sku: 'SKU001', qty: 10)],
        estimate: const PriceQuote(lines: [
          QuoteLine(
              sku: 'SKU001', name: 'P', qty: 10, unitPrice: 100, discount: 0)
        ], applied: [], total: 1000, discount: 0),
        estimatedAt: DateTime.utc(2026, 11, 2),
        snapshot: null,
        pendingOnlineRequest: const NewOrderRequest(
          clientOrderKey: '22222222-2222-4222-8222-222222222222',
          retailerId: 'retailer-id',
          lines: [CartLine(productId: 'p', sku: 'SKU001', qty: 10)],
        ),
      );

  // i % 5: 0 Allocating, 1 Quoted, 2 PaymentPending, 3 Delivering, 4 Delivered
  String statusOfFive(int i) => const [
        'Allocating',
        'Quoted',
        'PaymentPending',
        'Delivering',
        'Delivered'
      ][i % 5];

  group('pending chip: exact server filter over three statuses', () {
    test('first batch is the newest of all three statuses, in order', () async {
      final server = _Server(100, statusOfFive);
      await setUpRepository(server);
      final state = await settle(controller(SalesOrderGroup.pending));

      final expected = <int>[
        for (var i = 0; i < 100; i++)
          if (i % 5 < 3) i
      ].take(salesOrdersPageSize).map((i) => 'DH-$i').toList();
      expect(state.server.map((o) => o.code), expected);
      expect(state.totalCount, 60); // 20 + 20 + 20
      expect(state.hasMore, isTrue);
      // Only statuses the Backend accepts, the page size, never an unfiltered
      // or "Delivering" request.
      final statuses = server.orderRequests.map((v) => v['status']).toSet();
      expect(statuses, {'Allocating', 'Quoted', 'PaymentPending'});
      expect(
          server.orderRequests
              .every((v) => v['pageSize'] == salesOrdersPageSize),
          isTrue);
    });

    test('pages across statuses until exhausted: all 60, once, newest first',
        () async {
      final server = _Server(100, statusOfFive);
      await setUpRepository(server);
      final c = controller(SalesOrderGroup.pending);
      await settle(c);
      while (c.state.value!.hasMore) {
        await c.loadMore();
      }
      final codes = c.state.value!.server.map((o) => o.code).toList();
      expect(codes, hasLength(60));
      expect(codes.toSet(), hasLength(60));
      expect(codes, [
        for (var i = 0; i < 100; i++)
          if (i % 5 < 3) 'DH-$i'
      ]);
      // After the end no request is made.
      final before = server.orderRequests.length;
      await c.loadMore();
      expect(server.orderRequests.length, before);
    });

    test('a failed page loses nothing: the retry continues the same sequence',
        () async {
      final server = _Server(300, statusOfFive);
      await setUpRepository(server);
      final reference = controller(SalesOrderGroup.pending);
      await settle(reference);
      while (reference.state.value!.hasMore) {
        await reference.loadMore();
      }
      final expected =
          reference.state.value!.server.map((o) => o.code).toList();

      final c = controller(SalesOrderGroup.pending);
      await settle(c);
      server.failOnce = (v) => v['status'] == 'Quoted' && v['page'] == 2;
      await c.loadMore();
      await c.loadMore();
      var guard = 0;
      while (c.state.value!.hasMore && guard++ < 50) {
        await c.loadMore();
      }
      expect(c.state.value!.server.map((o) => o.code).toList(), expected);
    });

    test('search is sent with the status and combines with the chip', () async {
      final server = _Server(100, statusOfFive);
      await setUpRepository(server);
      final c = controller(SalesOrderGroup.pending, search: 'DH-1');
      final state = await settle(c);

      expect(server.orderRequests.every((v) => v['search'] == 'dh-1'), isTrue);
      // DH-1, DH-10..DH-19 and DH-100+ restricted to pending statuses.
      expect(
          state.server.map((o) => o.code).toList(),
          [
            for (var i = 0; i < 100; i++)
              if (i % 5 < 3 && 'dh-$i'.contains('dh-1')) 'DH-$i'
          ].take(salesOrdersPageSize).toList());
    });

    test('rejected chip merges its statuses and keeps the queue rows apart',
        () async {
      final server = _Server(
          60, (i) => i % 4 == 3 ? 'Delivered' : _statusesRejected[i % 3]);
      await setUpRepository(server);
      await pendingOrder(); // local, "Allocating": not part of this chip
      final state = await settle(controller(SalesOrderGroup.rejected));

      expect(state.orders.every((o) => o.status.isRejectedOrCancelled), isTrue);
      expect(state.orders.where((o) => o.isOffline), isEmpty);
      expect(state.totalCount, 45);
      expect(server.orderRequests.map((v) => v['status']).toSet(), {
        'QuoteRejected',
        'QuoteExpired',
        'Withdrawn',
        'AllocationFailed',
        'OutOfStock',
        'AllocationConflict',
      });
    });

    test('pending chip shows the pending queue row next to server rows',
        () async {
      final server = _Server(100, statusOfFive);
      await setUpRepository(server);
      await pendingOrder();
      final state = await settle(controller(SalesOrderGroup.pending));

      expect(state.orders.where((o) => o.isOffline), hasLength(1));
      expect(state.totalCount, 60); // the queue row is not in the total
    });

    test('refresh restarts the merge from the first batch', () async {
      final server = _Server(100, statusOfFive);
      await setUpRepository(server);
      final c = controller(SalesOrderGroup.pending);
      await settle(c);
      await c.loadMore();
      expect(c.state.value!.server, hasLength(2 * salesOrdersPageSize));
      await c.refresh();
      final state = await settle(c);
      expect(state.server, hasLength(salesOrdersPageSize));
      expect(state.server.first.code, 'DH-0');
    });
  });

  group('chips the Backend cannot filter are read in full', () {
    // i % 4: 0 Quoted, 1 Picking, 2 Delivering, 3 Delivered
    String statusOfFour(int i) =>
        const ['Quoted', 'Picking', 'Delivering', 'Delivered'][i % 4];

    test('in-progress chip scans every page (> 500) and filters exactly',
        () async {
      final server = _Server(650, statusOfFour);
      await setUpRepository(server);
      final c = controller(SalesOrderGroup.inProgress);
      var sawIncomplete = false;
      c.addListener((s) {
        if (s.valueOrNull?.scanning ?? false) sawIncomplete = true;
      });
      await settle(c);

      await idle(c);
      final state = c.state.value!;
      expect(sawIncomplete, isTrue); // flagged incomplete until the last page
      expect(state.scanning, isFalse);
      expect(state.server, hasLength(650));
      expect(state.orders, hasLength(325)); // Picking + Delivering only
      expect(
          state.orders.every((o) =>
              o.status.code == 'Picking' || o.status.code == 'Delivering'),
          isTrue);
      // Never a status filter (refused by the Backend), 100 per page.
      expect(server.orderRequests.every((v) => v['status'] == null), isTrue);
      expect(server.orderRequests.map((v) => v['page']),
          [for (var i = 1; i <= 7; i++) i]);
      expect(server.orderRequests.every((v) => v['pageSize'] == 100), isTrue);
    });

    test('delivered chip with a search reads only the matching orders',
        () async {
      final server = _Server(650, statusOfFour);
      await setUpRepository(server);
      final c = controller(SalesOrderGroup.delivered, search: 'dh-6');
      await settle(c);
      await idle(c);
      expect(server.orderRequests.every((v) => v['search'] == 'dh-6'), isTrue);
      expect(
          c.state.value!.orders.every((o) =>
              o.status.code == 'Delivered' &&
              o.code.toLowerCase().contains('dh-6')),
          isTrue);
    });

    test('a failed page keeps what is loaded; retry finishes the scan',
        () async {
      final server = _Server(650, statusOfFour);
      await setUpRepository(server);
      server.failOnce = (v) => v['page'] == 3;
      final c = controller(SalesOrderGroup.inProgress);
      await settle(c);
      await idle(c);

      var state = c.state.value!;
      expect(state.moreError, isNotNull);
      expect(state.server, hasLength(200));
      expect(state.scanning, isTrue); // still flagged incomplete

      await c.loadMore(); // retry from page 3
      await idle(c);
      state = c.state.value!;
      expect(state.server, hasLength(650));
      expect(state.scanning, isFalse);
    });

    test('offline chip: queue rows on the device are listed', () async {
      final server = _Server(40, statusOfFive);
      await setUpRepository(server);
      await pendingOrder();
      final state = await settle(controller(SalesOrderGroup.offline));
      expect(state.orders.where((o) => o.isOffline), hasLength(1));
      expect(state.orders.every((o) => o.isOffline), isTrue);
    });
  });

  group('dashboard counts', () {
    test('server aggregate: exact counts above 500, no order scan', () async {
      final server = _Server(0, statusOfFive)
        ..created = 1234
        ..rejected = 56;
      await setUpRepository(server);

      final counts = await salesTodayCounts(
          api: api,
          repository: repository,
          ownerUserId: '33333333-3333-4333-8333-333333333333',
          now: DateTime.utc(2026, 11, 19, 20));

      expect(counts.created, 1234);
      expect(counts.rejected, 56);
      expect(server.orderRequests, isEmpty);
      expect(server.aggregateRequests, hasLength(2));
      expect(server.aggregateRequests.first['uid'],
          '33333333-3333-4333-8333-333333333333');
    });

    test('day boundaries are Vietnam midnight (UTC+7)', () async {
      final server = _Server(0, statusOfFive);
      await setUpRepository(server);
      Future<List<String>> bounds(DateTime now) async {
        server.aggregateRequests.clear();
        await salesTodayCounts(
            api: api, repository: repository, ownerUserId: 'u', now: now);
        final v = server.aggregateRequests.first;
        return <String>[v['from'] as String, v['to'] as String];
      }

      // 20:00Z on the 19th is 03:00 on the 20th in Vietnam.
      expect(await bounds(DateTime.utc(2026, 11, 19, 20)),
          ['2026-11-19T17:00:00.000Z', '2026-11-20T17:00:00.000Z']);
      // 16:59Z is still 23:59 on the 19th; 17:00Z is already the 20th.
      expect(await bounds(DateTime.utc(2026, 11, 19, 16, 59)),
          ['2026-11-18T17:00:00.000Z', '2026-11-19T17:00:00.000Z']);
      expect(await bounds(DateTime.utc(2026, 11, 19, 17)),
          ['2026-11-19T17:00:00.000Z', '2026-11-20T17:00:00.000Z']);
    });

    test('rejected count asks only for rejected / cancelled statuses',
        () async {
      final server = _Server(0, statusOfFive);
      await setUpRepository(server);
      await salesTodayCounts(
          api: api,
          repository: repository,
          ownerUserId: 'u',
          now: DateTime.utc(2026, 11, 19, 20));
      final withStatus =
          server.aggregateRequests.firstWhere((v) => v.containsKey('st'));
      expect(
          withStatus['st'],
          containsAll(<String>[
            'QuoteRejected',
            'QuoteExpired',
            'Withdrawn',
            'AllocationFailed',
            'OutOfStock',
            'AllocationConflict',
          ]));
      expect(withStatus['st'], isNot(contains('Delivered')));
    });

    test('aggregate refused: uncapped scan stays exact above 500', () async {
      // Now is 03:00 in Vietnam (180 min into the day). One order every 10 s:
      // orders 0..1080 fall on today's date, 1081.. on the day before.
      final now = DateTime.utc(2026, 11, 19, 20);
      final server = _Server(
        1200,
        (i) => i % 7 == 0 ? 'Withdrawn' : 'Quoted',
        newest: now,
        step: const Duration(seconds: 10),
      )..failAggregate = true;
      await setUpRepository(server);

      final counts = await salesTodayCounts(
          api: api, repository: repository, ownerUserId: 'u', now: now);

      expect(counts.created, 1081);
      expect(counts.rejected, 155); // i = 0, 7, ... 1078
      // The scan stopped at the first older order: page 11 of 100.
      expect(server.orderRequests.map((v) => v['page']),
          [for (var i = 1; i <= 11; i++) i]);
    });

    test('network failure is not hidden as a count', () async {
      final server = _Server(0, statusOfFive)..offline = true;
      await setUpRepository(server);
      await expectLater(
          salesTodayCounts(
              api: api,
              repository: repository,
              ownerUserId: 'u',
              now: DateTime.utc(2026, 11, 19, 20)),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });

    test('local unsynchronised orders are added next to, not into, the total',
        () async {
      final server = _Server(0, statusOfFive)
        ..created = 10
        ..rejected = 2;
      await setUpRepository(server);
      await pendingOrder();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(const AppUser(
            id: '33333333-3333-4333-8333-333333333333',
            fullName: 'S',
            phone: '0',
            role: UserRole.sales,
            permissions: [
              'mobile-sales-sync',
              'mobile-sales-home',
              'mobile-sales-orders'
            ])),
        orderRepositoryProvider.overrideWithValue(repository),
        ordersApiProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);

      final stats = await container.read(salesOrderStatsProvider.future);

      // The unsent queue row (created now) is added beside the server counts.
      expect(stats.createdToday, 10 + 1);
      expect(stats.rejectedToday, 2);
      expect(stats.waiting, 3 * 3 + 1); // 3 server statuses x 3 + 1 local
      expect(stats.delivering, 3);
    });
  });
}
