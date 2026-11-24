import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/order_page.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/sales_orders_controller.dart';
import 'package:fscm_mobile/features/sales/orders/sales_orders_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class _Server implements ApiTransport {
  final pages = <int>[];
  bool failNext = false;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final vars = (request.body! as Map)['variables'] as Map;
    final page = vars['page'] as int;
    pages.add(page);
    if (failNext && page > 1) {
      failNext = false;
      throw const ApiException(kind: ApiErrorKind.server, message: 'boom');
    }
    const total = 2 * salesOrdersPageSize + 5;
    return ApiResponse(statusCode: 200, data: {
      'data': {
        'entities': {
          'orderReads': {
            'items': [
              for (var i = (page - 1) * salesOrdersPageSize;
                  i < page * salesOrdersPageSize && i < total;
                  i++)
                {
                  'id': 'id-$i',
                  'orderCode': 'DH-$i',
                  'retailerName': 'Retailer $i',
                  'status': 'Quoted',
                  'finalAmount': 1000,
                  'createdAt': DateTime.utc(2026, 11, 1)
                      .subtract(Duration(minutes: i))
                      .toIso8601String(),
                }
            ],
            'page': page,
            'pageSize': salesOrdersPageSize,
            'totalCount': total,
          },
        },
      },
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final queries = <SalesOrdersQuery>[];
  setUp(queries.clear);

  Future<(_Server, ProviderScope)> build(WidgetTester tester) async {
    late SalesOrdersController controller;
    final server = _Server();
    late OrderRepository repo;
    late AppDatabase database;
    final name = 'scroll_${DateTime.now().microsecondsSinceEpoch}.db';
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'device_code': 'TEST'});
      database = AppDatabase(databaseName: name);
      repo = OrderRepository(
        api: OrdersApi(ApiClient(transport: server, tokenReader: () => 't')),
        queue: OfflineOrderDao(database),
        syncState: SyncStateDao(database),
        device: DeviceIdentity(await SharedPreferences.getInstance()),
        ownerId: 'sales',
        isSales: true,
        isCurrentUser: () => true,
      );
      // Started outside the fake-async zone so its SQLite read completes.
      controller =
          SalesOrdersController(repo, search: '', isCurrentUser: () => true);
      while (controller.state.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await database.close();
        await deleteDatabase(p.join(await getDatabasesPath(), name));
      });
    });
    return (
      server,
      ProviderScope(
        overrides: [
          unreadNotificationsProvider.overrideWithValue(0),
          salesOrdersProvider.overrideWith((ref, query) {
            queries.add(query);
            // The prebuilt controller serves the first key; a new key (search
            // or chip) gets a fresh one, as in the app.
            return queries.length == 1
                ? controller
                : SalesOrdersController(_NoDbRepository(),
                    search: query.search,
                    group: query.group,
                    isCurrentUser: () => true);
          }),
        ],
        child: const MaterialApp(home: SalesOrdersScreen()),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }

  testWidgets('scrolling near the end loads the next page, then shows the end',
      (tester) async {
    final (server, app) = await build(tester);
    await tester.pumpWidget(app);
    await settle(tester);

    expect(server.pages, [1]);
    expect(find.text('DH-0'), findsOneWidget);

    for (var i = 0; i < 12 && server.pages.length < 3; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await settle(tester);
    }
    expect(server.pages, [1, 2, 3]); // once per page, never concurrent twice

    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Đã hiển thị tất cả đơn'), findsOneWidget);
    expect(server.pages, [1, 2, 3]); // nothing after the last page
  });

  testWidgets('a failed page shows a retry that continues from the same page',
      (tester) async {
    final (server, app) = await build(tester);
    await tester.pumpWidget(app);
    await settle(tester);

    server.failNext = true;
    for (var i = 0; i < 6 && find.text('Thử lại').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await settle(tester);
    }
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await settle(tester);
    expect(server.pages, [1, 2, 2]);
  });

  testWidgets('search is debounced and a chip changes the query key',
      (tester) async {
    final (_, app) = await build(tester);
    await tester.pumpWidget(app);
    await settle(tester);
    expect(queries.map((q) => q.search), ['']);

    await tester.enterText(find.byType(TextField), 'd');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'dh-1');
    await tester.pump(const Duration(milliseconds: 200));
    expect(queries, hasLength(1)); // still within the debounce window

    await tester.pump(const Duration(milliseconds: 400));
    expect(queries, hasLength(2));
    expect(queries.last.search, 'dh-1');

    await tester.tap(find.text('Chờ xử lý'));
    await tester.pump();
    expect(queries.last.group, SalesOrderGroup.pending);
    expect(queries.last.search, 'dh-1'); // search + chip together
  });
}

/// Answers instantly without SQLite, for controllers created in fake-async.
class _NoDbRepository implements OrderRepository {
  @override
  Future<List<OfflineOrder>> queueEntries() async => const <OfflineOrder>[];

  @override
  Future<OrderPage> fetchOrdersPage(
          {required int page,
          required int pageSize,
          String? search,
          String? status}) async =>
      const OrderPage(items: <Order>[], page: 1, pageSize: 20, totalCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
