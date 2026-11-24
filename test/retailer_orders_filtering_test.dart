import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_orders_screen.dart';

/// UI.7A.1: what the Retailer order list really shows when the Backend cannot
/// filter by active/history or date. The REAL controller and the REAL screen
/// run over a fake transport serving 35 orders in pages of 10:
///   0..14  Completed, 100 days old   (history, outside 7/30 days)
///   15..24 Completed, 1 day old      (history, recent)
///   25..34 Quoted, 3 days old        (active, recent)
class _FakeNotifications extends StateNotifier<AsyncValue<NotificationsState>>
    implements NotificationsController {
  _FakeNotifications()
      : super(const AsyncData(NotificationsState(
            local: <AppNotification>[],
            server: <AppNotification>[],
            page: 1,
            hasMore: false)));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _retailer = AppUser.fromJson(<String, dynamic>{
  'id': 'u1',
  'fullName': 'Cửa hàng An Phú',
  'email': 'an@example.com',
  'role': 'Retailer',
  'retailerCode': '10004127',
  'retailerName': 'Cửa hàng An Phú',
  'scope': <String, dynamic>{},
});

const _total = 35;

Map<String, dynamic> _item(int i) {
  final active = i >= 25;
  final age = i < 15 ? 100 : (active ? 3 : 1);
  return <String, dynamic>{
    'id': 'order-$i',
    'orderCode': 'DH-${(100000 + i)}',
    'status': active ? 'Quoted' : 'Completed',
    'lineCount': 1,
    'totalCartons': 1,
    'finalAmount': 1000,
    'createdAt': AppClock.now().subtract(Duration(days: age)).toIso8601String(),
  };
}

class _Server implements ApiTransport {
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  Object? failPage; // page that throws once
  Completer<void>? gate; // holds the next answer until completed

  List<int> get pages => [for (final r in requests) r['page'] as int];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final vars = (request.body! as Map<String, dynamic>)['variables']
        as Map<String, dynamic>;
    requests.add(vars);
    final page = vars['page'] as int;
    final size = vars['pageSize'] as int;
    if (failPage == page) {
      failPage = null;
      throw const ApiException(kind: ApiErrorKind.server, message: 'boom');
    }
    final held = gate;
    if (held != null && page == 2) {
      gate = null;
      await held.future;
    }
    final from = (page - 1) * size;
    return ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{
          'orderReads': <String, dynamic>{
            'items': [
              for (var i = from; i < from + size && i < _total; i++) _item(i)
            ],
            'page': page,
            'pageSize': size,
            'totalCount': _total,
          },
        },
      },
    });
  }
}

Future<_Server> _pump(WidgetTester tester, {double scale = 1.0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 6000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final server = _Server();
  final client = ApiClient(transport: server, tokenReader: () => 'token');
  addTearDown(client.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_retailer),
      retailerOrdersProvider.overrideWith((ref, search) =>
          RetailerOrdersController(OrdersApi(client),
              search: search, isCurrentUser: () => true)),
      retailerTodoProvider.overrideWith((ref) async => const RetailerTodo(
          quotesToConfirm: 0,
          paymentsPending: 0,
          deliveriesToReceive: 0,
          overdueCount: 0,
          overdueAmount: 0,
          dueSoonCount: 0,
          dueSoonAmount: 0,
          loyaltyPoints: 0)),
      notificationsProvider.overrideWith((ref) => _FakeNotifications()),
      notificationBadgeProvider.overrideWith((ref) async => 0),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const RtOrdersScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

int _tiles() => find.byType(RtOrderTile, skipOffstage: false).evaluate().length;

void main() {
  testWidgets(
      'active tab: first pages hold no active order, so later pages are read '
      'once each until the tab is filled', (tester) async {
    final server = await _pump(tester);
    // pages 1,2 have none, page 3 has 5 (<10) so page 4 is read; then end.
    expect(server.pages, [1, 2, 3, 4]);
    expect(_tiles(), 10);
    expect(
        find.textContaining('Đã tải 35/35', skipOffstage: false), findsWidgets);
    expect(find.text('Tải thêm đơn', skipOffstage: false), findsNothing);
    // Nothing is requested after the last page, however long we wait.
    await tester.pump(const Duration(seconds: 2));
    expect(server.pages, [1, 2, 3, 4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history tab with a full first page does not fetch more',
      (tester) async {
    final server = await _pump(tester);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(server.pages, [1, 2, 3, 4]); // nothing new: 25 history rows loaded
    expect(_tiles(), 25);
  });

  testWidgets('7-day filter reads pages only until it holds 10 recent orders',
      (tester) async {
    final server = await _pump(tester);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 ngày'));
    await tester.pumpAndSettle();
    expect(_tiles(), 10); // 15..24 only, the 100-day-old rows are hidden
    expect(server.pages.toSet().length, server.pages.length); // no duplicates

    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(_tiles(), 25);
  });

  testWidgets('a failed page stops automatic loading; retry continues',
      (tester) async {
    final server = _Server();
    server.failPage = 2;
    // Build manually to set failPage before the first load.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(transport: server, tokenReader: () => 'token');
    addTearDown(client.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_retailer),
        retailerOrdersProvider.overrideWith((ref, search) =>
            RetailerOrdersController(OrdersApi(client),
                search: search, isCurrentUser: () => true)),
        retailerTodoProvider.overrideWith((ref) async => const RetailerTodo(
            quotesToConfirm: 0,
            paymentsPending: 0,
            deliveriesToReceive: 0,
            overdueCount: 0,
            overdueAmount: 0,
            dueSoonCount: 0,
            dueSoonAmount: 0,
            loyaltyPoints: 0)),
        notificationsProvider.overrideWith((ref) => _FakeNotifications()),
        notificationBadgeProvider.overrideWith((ref) async => 0),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const RtOrdersScreen()),
    ));
    await tester.pumpAndSettle();

    expect(server.pages, [1, 2]); // stops after the failure: no loop
    await tester.pump(const Duration(seconds: 2));
    expect(server.pages, [1, 2]);
    expect(find.text('Tải thêm đơn', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Tải thêm đơn', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(server.pages, [1, 2, 2, 3, 4]); // retry, then continues once each
    expect(_tiles(), 10);
  });

  testWidgets(
      'changing the range while a page is in flight adds no duplicate '
      'request', (tester) async {
    final gate = Completer<void>();
    final server = _Server()..gate = gate;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(transport: server, tokenReader: () => 'token');
    addTearDown(client.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_retailer),
        retailerOrdersProvider.overrideWith((ref, search) =>
            RetailerOrdersController(OrdersApi(client),
                search: search, isCurrentUser: () => true)),
        retailerTodoProvider.overrideWith((ref) async => const RetailerTodo(
            quotesToConfirm: 0,
            paymentsPending: 0,
            deliveriesToReceive: 0,
            overdueCount: 0,
            overdueAmount: 0,
            dueSoonCount: 0,
            dueSoonAmount: 0,
            loyaltyPoints: 0)),
        notificationsProvider.overrideWith((ref) => _FakeNotifications()),
        notificationBadgeProvider.overrideWith((ref) async => 0),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const RtOrdersScreen()),
    ));
    await tester.pump();
    await tester.pump();
    expect(server.pages, [1, 2]); // page 2 is held at the gate

    await tester.tap(find.text('30 ngày'));
    await tester.pump();
    await tester.pump();
    expect(server.pages, [1, 2]); // still one request in flight

    gate.complete();
    await tester.pumpAndSettle();
    expect(server.pages.toSet().length, server.pages.length); // no duplicates
    expect(server.pages.first, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search restarts at page 1 with the server argument',
      (tester) async {
    final server = await _pump(tester);
    final before = server.requests.length;
    await tester.enterText(find.byType(TextField), 'DH-100');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final fresh = server.requests.skip(before).toList();
    expect(fresh.first['page'], 1);
    expect(fresh.first['search'], 'dh-100');
    expect(fresh.every((r) => r['search'] == 'dh-100'), isTrue);
  });

  testWidgets('empty states say whether more data may exist (1.6x text)',
      (tester) async {
    await _pump(tester, scale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
