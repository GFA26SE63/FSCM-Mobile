import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/sales_orders_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Serves `total` server orders, newest first, in the requested page size.
class _Server implements ApiTransport {
  _Server(this.total);

  int total;
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  bool offline = false;
  Object? failPage; // page number that throws once
  Completer<void>? gate; // holds responses until completed
  List<int> Function(int page, int size)? idsOverride;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final vars = ((request.body! as Map<String, dynamic>)['variables']
        as Map<String, dynamic>);
    requests.add(vars);
    if (offline) throw const ApiException.network();
    final page = vars['page'] as int;
    final size = vars['pageSize'] as int;
    if (failPage == page) {
      failPage = null;
      throw const ApiException(kind: ApiErrorKind.server, message: 'boom');
    }
    if (gate != null) await gate!.future;
    final ids = idsOverride?.call(page, size) ??
        <int>[
          for (var i = (page - 1) * size; i < page * size && i < total; i++) i
        ];
    return ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{
          'orderReads': <String, dynamic>{
            'items': ids.map(_summary).toList(),
            'page': page,
            'pageSize': size,
            'totalCount': total,
          },
        },
      },
    });
  }
}

/// Order 0 is the newest.
Map<String, dynamic> _summary(int i) => <String, dynamic>{
      'id': 'id-$i',
      'orderCode': 'DH-$i',
      'retailerCode': 'RT1',
      'retailerName': 'Retailer',
      'status': 'Quoted',
      'finalAmount': 1000,
      'source': 'Online',
      'version': 1,
      'createdAt': DateTime.utc(2026, 11, 1)
          .subtract(Duration(minutes: i))
          .toIso8601String(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late OfflineOrderDao queue;
  late OrderRepository repository;
  late _Server server;
  final controllers = <SalesOrdersController>[];

  Future<void> setUpRepository(int total) async {
    SharedPreferences.setMockInitialValues({'device_code': 'TEST'});
    final name = 'sales_paging_${DateTime.now().microsecondsSinceEpoch}.db';
    database = AppDatabase(databaseName: name);
    queue = OfflineOrderDao(database);
    server = _Server(total);
    final client = ApiClient(transport: server, tokenReader: () => 'token');
    repository = OrderRepository(
      api: OrdersApi(client),
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

  SalesOrdersController controller({String search = ''}) {
    final c = SalesOrdersController(repository,
        search: search, isCurrentUser: () => true);
    controllers.add(c);
    return c;
  }

  Future<SalesOrdersState> settle(SalesOrdersController c) async {
    for (var i = 0; i < 1000 && c.state.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return c.state.value!;
  }

  Future<OfflineOrder> pendingOrder() async {
    const request = NewOrderRequest(
      clientOrderKey: '22222222-2222-4222-8222-222222222222',
      retailerId: 'retailer-id',
      lines: [CartLine(productId: 'product-id', sku: 'SKU001', qty: 10)],
    );
    return repository.createOffline(
      orderStep: 1,
      retailer: Retailer.fromJson(
          {'id': 'retailer-id', 'code': 'RT001', 'name': 'T', 'address': 'A'}),
      lines: request.lines,
      estimate: const PriceQuote(lines: [
        QuoteLine(
            sku: 'SKU001', name: 'P', qty: 10, unitPrice: 100, discount: 0)
      ], applied: [], total: 1000, discount: 0),
      estimatedAt: DateTime.utc(2026, 11, 2),
      snapshot: null,
      pendingOnlineRequest: request,
    );
  }

  group('paging', () {
    test('first request is 20 orders, not the whole dataset', () async {
      await setUpRepository(250);
      final c = controller();
      final state = await settle(c);

      expect(state.server, hasLength(20));
      expect(state.totalCount, 250);
      expect(state.hasMore, isTrue);
      expect(server.requests, hasLength(1));
      expect(server.requests.single['page'], 1);
      expect(server.requests.single['pageSize'], 20);
    });

    test('loads page by page past 100 and 250 records, then stops', () async {
      await setUpRepository(260);
      final c = controller();
      await settle(c);
      while (c.state.value!.hasMore) {
        await c.loadMore();
      }
      final state = c.state.value!;

      expect(state.server, hasLength(260));
      expect(state.server.map((o) => o.id).toSet(), hasLength(260));
      expect(server.requests.map((r) => r['page']),
          [for (var i = 1; i <= 13; i++) i]);
      expect(server.requests.every((r) => r['pageSize'] == 20), isTrue);

      await c.loadMore(); // after the last page: nothing is requested
      expect(server.requests, hasLength(13));
      expect(state.hasMore, isFalse);
    });

    test('empty result', () async {
      await setUpRepository(0);
      final state = await settle(controller());
      expect(state.orders, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('last partial page', () async {
      await setUpRepository(25);
      final c = controller();
      await settle(c);
      await c.loadMore();
      expect(c.state.value!.server, hasLength(25));
      expect(c.state.value!.hasMore, isFalse);
    });

    test('a failed page keeps loaded data and retry continues', () async {
      await setUpRepository(60);
      final c = controller();
      await settle(c);
      server.failPage = 2;
      await c.loadMore();

      var state = c.state.value!;
      expect(state.server, hasLength(20));
      expect(state.moreError, isNotNull);
      expect(state.hasMore, isTrue);

      await c.loadMore(); // retry
      state = c.state.value!;
      expect(state.server, hasLength(40));
      expect(state.moreError, isNull);
    });

    test('concurrent loadMore calls make one request', () async {
      await setUpRepository(100);
      final c = controller();
      await settle(c);
      server.gate = Completer<void>();
      final before = server.requests.length;

      final a = c.loadMore();
      final b = c.loadMore();
      final d = c.loadMore();
      await Future<void>.delayed(Duration.zero);
      server.gate!.complete();
      await Future.wait([a, b, d]);

      expect(server.requests.length - before, 1);
      expect(c.state.value!.server, hasLength(40));
    });

    test('overlapping pages are de-duplicated', () async {
      await setUpRepository(40);
      server.idsOverride = (page, size) => page == 1
          ? [for (var i = 0; i < 20; i++) i]
          : [for (var i = 10; i < 30; i++) i];
      final c = controller();
      await settle(c);
      await c.loadMore();
      expect(c.state.value!.server.map((o) => o.id).toSet(), hasLength(30));
    });

    test('a page that adds nothing new ends paging (bad total cannot loop)',
        () async {
      await setUpRepository(1000);
      server.idsOverride = (page, size) => [for (var i = 0; i < 20; i++) i];
      final c = controller();
      await settle(c);
      await c.loadMore();
      expect(c.state.value!.hasMore, isFalse);
    });
  });

  group('search and refresh', () {
    test('search is a server argument and starts again at page 1', () async {
      await setUpRepository(100);
      final all = controller();
      await settle(all);
      await all.loadMore();

      final searched = controller(search: ' Dh-7 ');
      await settle(searched);

      expect(server.requests.last['search'], 'dh-7');
      expect(server.requests.last['page'], 1);
      expect(searched.state.value!.page, 1);
    });

    test('a late response of the previous refresh cannot overwrite a newer one',
        () async {
      await setUpRepository(30);
      final c = controller();
      await settle(c);

      server.gate = Completer<void>();
      server.total = 5;
      final stale = c.refresh(); // held at the gate
      await Future<void>.delayed(Duration.zero);
      final gate = server.gate!;
      server.gate = null;
      server.total = 7;
      await c.refresh(); // newer, answered immediately
      gate.complete();
      await stale;
      await Future<void>.delayed(Duration.zero);

      expect(c.state.value!.totalCount, 7);
    });

    test('pull-to-refresh resets to page 1 and keeps pending local orders',
        () async {
      await setUpRepository(60);
      final pending = await pendingOrder();
      final c = controller();
      await settle(c);
      await c.loadMore();
      expect(c.state.value!.server, hasLength(40));

      await c.refresh();
      final state = await settle(c);

      expect(state.server, hasLength(20));
      expect(state.page, 1);
      expect(state.orders.where((o) => o.offlineCode == pending.localCode),
          hasLength(1));
      expect(state.totalCount, 60); // queue rows are not in the server total
    });
  });

  group('offline queue', () {
    test('pending order stays visible across pages and is not server-confirmed',
        () async {
      await setUpRepository(60);
      final pending = await pendingOrder();
      final c = controller();
      await settle(c);
      await c.loadMore();

      final orders = c.state.value!.orders;
      final local = orders.where((o) => o.isOffline).toList();
      expect(local, hasLength(1));
      expect(local.single.offlineCode, pending.localCode);
      expect(local.single.syncStatus, SyncStatus.pending);
      expect(local.single.id, isEmpty);
      expect(orders, hasLength(41));
      expect(c.state.value!.totalCount, 60);
      // Newest first: the pending order (Nov 2) precedes every server row.
      expect(orders.first.isOffline, isTrue);
    });

    test('offline-only: queue shown, no paging, nothing lost', () async {
      await setUpRepository(60);
      await pendingOrder();
      server.offline = true;
      final c = controller();
      final state = await settle(c);

      expect(state.offlineOnly, isTrue);
      expect(state.orders.single.isOffline, isTrue);
      expect(state.hasMore, isFalse);
      final before = server.requests.length;
      await c.loadMore();
      expect(server.requests.length, before);
      expect(await queue.all(ownerId: 'sales'), hasLength(1));
    });

    test('refresh while offline keeps the pending order', () async {
      await setUpRepository(60);
      await pendingOrder();
      final c = controller();
      await settle(c);
      server.offline = true;
      await c.refresh();
      final state = await settle(c);
      expect(state.offlineOnly, isTrue);
      expect(state.orders.where((o) => o.isOffline), hasLength(1));
    });

    test(
        'a synced offline order is shown once, before and after its page loads',
        () async {
      await setUpRepository(60);
      final draft = await pendingOrder();
      // Synchronised as DH-30: it sits on the server's second page.
      final sending = await queue.claimForSend(draft.clientRequestId,
          ownerId: 'sales', now: DateTime.utc(2026, 11, 2));
      final synced = sending.copyWith(
        status: SyncStatus.synced,
        syncedAt: DateTime.utc(2026, 11, 2),
        serverOrderCode: 'DH-30',
        serverOrder: Order.fromJson(_summary(30)),
      );
      expect(
          await queue.finishAttempt(synced,
              ownerId: 'sales', attemptedAt: sending.lastAttemptAt!),
          isTrue);

      final c = controller();
      var state = await settle(c);
      // Page 1 does not hold DH-30: the local copy is the only DH-30 row.
      expect(state.orders.where((o) => o.displayCode == 'DH-30'), hasLength(1));
      expect(state.orders.where((o) => o.isOffline), hasLength(1));

      await c.loadMore(); // page 2 now brings the server's DH-30
      state = c.state.value!;
      final dh30 = state.orders.where((o) => o.displayCode == 'DH-30').toList();
      expect(dh30, hasLength(1));
      expect(dh30.single.isOffline, isFalse); // the server row replaced it
    });

    test('queue rows are searched locally when the server cannot', () async {
      await setUpRepository(60);
      final pending = await pendingOrder();
      final hit = controller(search: pending.localCode.toLowerCase());
      expect(
          (await settle(hit)).orders.where((o) => o.isOffline), hasLength(1));

      final miss = controller(search: 'zzz-no-match');
      expect((await settle(miss)).orders.where((o) => o.isOffline), isEmpty);
    });
  });
}
