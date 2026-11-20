import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/features/sales/home/sales_home_screen.dart';
import 'package:fscm_mobile/features/sales/orders/sales_orders_screen.dart';
import 'package:fscm_mobile/features/sales/products/product_list_screen.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

/// Presentation-only checks for the redesigned Sales home (UI.3.1): all data
/// comes from overridden providers; nothing here touches the real data layer.
class _FakeSync extends StateNotifier<SyncState> implements SyncService {
  _FakeSync() : super(const SyncState());
  int refreshes = 0;

  @override
  Future<void> refreshSnapshot() async => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNetwork extends StateNotifier<NetworkState>
    implements NetworkMonitor {
  _FakeNetwork() : super(const NetworkState(deviceOnline: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotifications extends StateNotifier<AsyncValue<NotificationsState>>
    implements NotificationsController {
  _FakeNotifications()
      : super(AsyncData(NotificationsState(
          local: const <AppNotification>[],
          server: <AppNotification>[
            AppNotification(
                id: 'n1',
                text: 'Đơn DH-001 đã được duyệt.',
                createdAt: DateTime(2026, 11, 20)),
          ],
          page: 1,
          hasMore: false,
        )));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _sales = AppUser.fromJson(<String, dynamic>{
  'id': 'u1',
  'fullName': 'Nguyễn Văn An',
  'email': 'an@example.com',
  'role': 'Sales',
  'scope': <String, dynamic>{},
});

const _widths = <double>[360, 390];
const _scales = <double>[1.0, 1.3, 1.6];

void _phone(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 700);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget home, List<Override> overrides, double scale) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

void main() {
  for (final width in _widths) {
    for (final scale in _scales) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('sales home: no overflow, actions reachable ($tag)',
          (tester) async {
        _phone(tester, width);
        final sync = _FakeSync();
        await tester.pumpWidget(_host(
            const SalesHomeScreen(),
            [
              currentUserProvider.overrideWithValue(_sales),
              syncServiceProvider.overrideWith((ref) => sync),
              networkMonitorProvider.overrideWith((ref) => _FakeNetwork()),
              salesOrderStatsProvider.overrideWith((ref) async =>
                  const SalesOrderStats(
                      createdToday: 3,
                      waiting: 2,
                      rejectedToday: 1,
                      delivering: 4)),
              offlineQueueProvider
                  .overrideWith((ref) async => const <OfflineOrder>[]),
              catalogProvider
                  .overrideWith((ref) => Completer<CatalogData>().future),
              receivablesProvider
                  .overrideWith((ref) async => const <Receivable>[]),
              notificationsProvider.overrideWith((ref) => _FakeNotifications()),
              notificationBadgeProvider.overrideWith((ref) async => 1),
              salesKpiProvider
                  .overrideWith((ref, period) => Completer<SalesKpi>().future),
            ],
            scale));
        await tester.pump();
        await tester.pump();

        expect(find.text('Xin chào, Nguyễn Văn An'), findsOneWidget);
        final list = find.byType(Scrollable).first;
        for (final label in <String>[
          'Tạo đơn hàng mới',
          'Mở hàng đợi',
          'Đơn hôm nay',
          'Đã tạo',
          'Khuyến mãi đang chạy',
          'Khai báo điểm bán',
          'Đơn đang giao',
        ]) {
          await tester.scrollUntilVisible(find.text(label), 200,
              scrollable: list);
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(tester.takeException(), isNull);
        expect(sync.refreshes, 0, reason: 'render must not sync');
      });

      testWidgets('sales orders tile: long Vietnamese text wraps ($tag)',
          (tester) async {
        _phone(tester, width);
        final order = Order.fromJson(<String, dynamic>{
          'id': 'order-1',
          'orderCode': 'DH-001057-RẤT-DÀI-ĐỂ-THỬ-NGẮT-DÒNG',
          'retailerId': 'r1',
          'retailerCode': '10004127',
          'retailerName':
              'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé Quận 1',
          'status': 'Quoted',
          'finalAmount': 12345678,
        });
        await tester.pumpWidget(_host(
            Scaffold(
                body:
                    ListView(children: <Widget>[SalesOrderTile(order: order)])),
            const [],
            scale));
        await tester.pump();
        expect(find.textContaining('Cửa hàng tạp hóa'), findsOneWidget);
        expect(find.byType(SalesOrderTile), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('sales products: cards and filters usable ($tag)',
          (tester) async {
        _phone(tester, width);
        final json = mobileSnapshotFixture();
        final products =
            (json['products'] as List).cast<Map<String, dynamic>>();
        products.first['name'] =
            'Sữa tươi tiệt trùng ít đường hộp giấy 180ml thùng 48 hộp đặc biệt';
        final data = CatalogData.fromSnapshot(SyncSnapshot.fromJson(json));
        await tester.pumpWidget(_host(
            const ProductListScreen(),
            [
              networkMonitorProvider.overrideWith((ref) => _FakeNetwork()),
              catalogProvider.overrideWith((ref) async => data),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Tất cả'), findsOneWidget);
        expect(find.textContaining('Sữa tươi tiệt trùng'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.textContaining('Sữa tươi tiệt trùng'));
        await tester.pumpAndSettle();
        expect(find.text('SKU'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
