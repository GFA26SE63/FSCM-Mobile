import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_orders_screen.dart';

/// The overview card, search and time chips are part of the order list's single
/// scroll view (they scroll away with it); the AppBar and tabs stay fixed.
/// REAL controller + REAL screen over a fake transport: 45 orders in pages of
/// 10; 0..29 are active (Quoted), 30..44 history (Completed), all recent.
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

const _total = 45;

Map<String, dynamic> _item(int i) => <String, dynamic>{
      'id': 'order-$i',
      'orderCode': 'DH-${100000 + i}',
      'status': i < 30 ? 'Quoted' : 'Completed',
      'lineCount': 1,
      'totalCartons': 1,
      'finalAmount': 1000,
      'createdAt':
          AppClock.now().subtract(const Duration(days: 1)).toIso8601String(),
    };

class _Server implements ApiTransport {
  final List<Map<String, dynamic>> requests = <Map<String, dynamic>>[];
  List<int> get pages => [for (final r in requests) r['page'] as int];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final vars = (request.body! as Map<String, dynamic>)['variables']
        as Map<String, dynamic>;
    requests.add(vars);
    final page = vars['page'] as int;
    final size = vars['pageSize'] as int;
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

Future<_Server> _pump(WidgetTester tester, double width, double scale,
    {double height = 720}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
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
          quotesToConfirm: 2,
          paymentsPending: 1,
          deliveriesToReceive: 0,
          overdueCount: 0,
          overdueAmount: 0,
          dueSoonCount: 0,
          dueSoonAmount: 0,
          loyaltyPoints: 1200)),
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

/// Bottom of the fixed AppBar (title + tabs): anything above it is hidden.
double _appBarBottom(WidgetTester tester) =>
    tester.getRect(find.byType(AppBar)).bottom;

bool _headerVisible(WidgetTester tester) {
  final field = find.text('Tìm mã đơn');
  // A sliver scrolled far off is no longer built at all.
  if (field.evaluate().isEmpty) return false;
  final rect = tester.getRect(field);
  return rect.bottom > _appBarBottom(tester);
}

void main() {
  for (final width in <double>[360, 390]) {
    for (final scale in <double>[1.0, 1.3, 1.6]) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('header scrolls away with the list and returns ($tag)',
          (tester) async {
        final server = await _pump(tester, width, scale);
        expect(find.text('Việc cần làm'), findsOneWidget);
        expect(find.text('Tìm mã đơn'), findsOneWidget);
        expect(find.text('Tích điểm · 1200 điểm'), findsOneWidget);
        expect(find.text('7 ngày'), findsOneWidget);
        expect(_headerVisible(tester), isTrue);
        final list = find.byType(NestedScrollView);

        await tester.drag(list, const Offset(0, -900));
        await tester.pump();
        expect(_headerVisible(tester), isFalse);
        expect(find.text('Việc cần làm').hitTestable(), findsNothing);
        expect(find.text('7 ngày').hitTestable(), findsNothing);
        // The fixed parts stay: AppBar tabs.
        expect(find.text('Đang xử lý'), findsOneWidget);
        expect(find.text('Lịch sử'), findsOneWidget);

        // Reaching the end of the loaded page reads the next server page.
        for (var i = 0; i < 6 && server.pages.length < 2; i++) {
          await tester.drag(list, const Offset(0, -1200));
          await tester.pumpAndSettle();
        }
        expect(server.pages.first, 1);
        expect(server.pages, contains(2));
        expect(server.pages.toSet().length, server.pages.length);

        // Back to the top: the header is back, nothing was lost.
        for (var i = 0; i < 8; i++) {
          await tester.drag(list, const Offset(0, 1500));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(_headerVisible(tester), isTrue);
        expect(find.text('Việc cần làm').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'tabs keep the time filter; search and refresh still work '
          '($tag)', (tester) async {
        final server = await _pump(tester, width, scale, height: 4000);
        await tester.tap(find.text('7 ngày'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lịch sử'));
        await tester.pumpAndSettle();
        // Same header, same selected range, history rows.
        expect(find.text('Tìm mã đơn'), findsOneWidget);
        expect(find.text('Việc cần làm'), findsOneWidget);
        expect(find.textContaining('DH-100030'), findsOneWidget);
        expect(find.textContaining('DH-100000'), findsNothing);
        await tester.tap(find.text('Đang xử lý'));
        await tester.pumpAndSettle();
        // The default order is newest-first, so the most recently loaded
        // active page is displayed first after returning to this tab.
        expect(find.textContaining('DH-100020'), findsOneWidget);

        // Pull to refresh re-reads page 1.
        final before = server.requests.length;
        await tester.fling(
            find.text('Việc cần làm'), const Offset(0, 2500), 1000);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(server.requests.length, greaterThan(before));
        expect(server.pages.last, 1);

        // Search is a server argument and restarts at page 1.
        final mark = server.requests.length;
        await tester.enterText(find.byType(TextField), 'DH-1000');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        final fresh = server.requests.skip(mark).toList();
        expect(fresh.first['page'], 1);
        expect(fresh.first['search'], 'dh-1000');
        expect(find.byType(TextField), findsOneWidget); // field survives
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'swipe and tap switch tabs; state and requests stay '
          'consistent ($tag)', (tester) async {
        final server = await _pump(tester, width, scale, height: 4000);
        // Only the selected tab drives loading: the first page already fills
        // "Đang xử lý", so the hidden history tab triggers nothing.
        expect(server.pages, [1]);
        await tester.enterText(find.byType(TextField), 'DH-1');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        final searchPages = server.pages.length;
        await tester.tap(find.text('7 ngày'));
        await tester.pumpAndSettle();
        expect(find.textContaining('DH-100000'), findsOneWidget);

        // Horizontal swipe on the list opens "Lịch sử".
        await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
        await tester.pumpAndSettle();
        final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
        expect(tabs.index, 1);
        expect(find.textContaining('DH-100000'), findsNothing);
        // One header only: search text, range and loaded data are kept.
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).controller,
            isNotNull);
        expect(find.text('Việc cần làm'), findsOneWidget);
        // The selected history tab keeps reading pages, each exactly once.
        expect(server.pages.length, greaterThan(searchPages));
        // After the search restarted at page 1, no page was requested twice.
        final later = server.pages.skip(1).toList();
        expect(later.toSet().length, later.length);

        // Swipe back and tap: both directions work.
        await tester.drag(find.byType(TabBarView), const Offset(600, 0));
        await tester.pumpAndSettle();
        expect(tabs.index, 0);
        await tester.tap(find.text('Lịch sử'));
        await tester.pumpAndSettle();
        expect(tabs.index, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'swiping is horizontal only: the header still scrolls away '
          '($tag)', (tester) async {
        await _pump(tester, width, scale);
        await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
        await tester.pumpAndSettle();
        final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
        expect(tabs.index, 1);
        await tester.drag(find.byType(NestedScrollView), const Offset(0, -900));
        await tester.pump();
        expect(_headerVisible(tester), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
