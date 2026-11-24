import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/debts/debts_screen.dart';
import 'package:fscm_mobile/features/sales/orders/order_confirm_sheet.dart';
import 'package:fscm_mobile/features/sales/products/promotions_screen.dart';
import 'package:fscm_mobile/features/sales/retailers/retailer_detail_screen.dart';
import 'package:fscm_mobile/features/sales/retailers/retailer_list_screen.dart';
import 'package:fscm_mobile/features/sales/sync/sync_queue_screen.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

/// UI.3C responsive checks (360/390 dp, 1.0/1.3/1.6 text scale) for the
/// remaining Sales screens. Data comes from provider overrides / fixtures.
class _FakeSync extends StateNotifier<SyncState> implements SyncService {
  _FakeSync() : super(const SyncState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNetwork extends StateNotifier<NetworkState>
    implements NetworkMonitor {
  _FakeNetwork() : super(const NetworkState(deviceOnline: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _widths = <double>[360, 390];
const _scales = <double>[1.0, 1.3, 1.6];

void _phone(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 720);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _host(Widget home, List<Override> overrides, double scale) =>
    ProviderScope(
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

CatalogData _catalog({String? retailerName}) {
  final json = mobileSnapshotFixture();
  final retailers = (json['retailers'] as List).cast<Map<String, dynamic>>();
  retailers.first['name'] = retailerName ??
      'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé Quận Một';
  retailers.first['address'] =
      '123/45/6 Đường Nguyễn Thị Minh Khai, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh';
  return CatalogData.fromSnapshot(SyncSnapshot.fromJson(json));
}

Future<void> _see(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
  }
  expect(target, findsOneWidget);
}

void main() {
  for (final width in _widths) {
    for (final scale in _scales) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('retailer list: long names wrap, search present ($tag)',
          (tester) async {
        _phone(tester, width);
        final data = _catalog();
        await tester.pumpWidget(_host(
            const RetailerListScreen(),
            [
              networkMonitorProvider.overrideWith((ref) => _FakeNetwork()),
              catalogProvider.overrideWith((ref) async => data),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await _see(tester, find.textContaining('Cửa hàng tạp hóa'));
        await _see(tester, find.textContaining('Mã điểm bán: 10000001'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('retailer detail: info card and order action ($tag)',
          (tester) async {
        _phone(tester, width);
        final data = _catalog();
        await tester.pumpWidget(_host(
            const RetailerDetailScreen(code: '10000001'),
            [
              networkMonitorProvider.overrideWith((ref) => _FakeNetwork()),
              catalogProvider.overrideWith((ref) async => data),
            ],
            scale));
        await tester.pumpAndSettle();
        await _see(tester, find.text('Thông tin điểm bán'));
        await _see(tester, find.text('Chuẩn bị đơn ngoại tuyến'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('promotions: cards and retailer filter ($tag)',
          (tester) async {
        _phone(tester, width);
        final data = _catalog();
        await tester.pumpWidget(_host(
            const PromotionsScreen(),
            [
              networkMonitorProvider.overrideWith((ref) => _FakeNetwork()),
              catalogProvider.overrideWith((ref) async => data),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('debts: empty state and filters ($tag)', (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            const DebtsScreen(),
            [
              receivablesProvider
                  .overrideWith((ref) async => const <Receivable>[]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Tổng còn phải thu'), findsOneWidget);
        expect(find.text('Quá hạn'), findsOneWidget);
        await _see(tester, find.text('Không có khoản công nợ phù hợp.'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('sync queue: summary, update button, empty tab ($tag)',
          (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            const SyncQueueScreen(),
            [
              syncServiceProvider.overrideWith((ref) => _FakeSync()),
              offlineQueueProvider
                  .overrideWith((ref) async => const <OfflineOrder>[]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Dữ liệu trên máy lúc'), findsOneWidget);
        expect(find.text('Cập nhật dữ liệu đồng bộ'), findsOneWidget);
        expect(find.text('Không có bản nháp trong mục này.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('order confirm sheet: lines, totals and actions ($tag)',
          (tester) async {
        _phone(tester, width);
        final data = _catalog();
        final retailer = data.retailers.first;
        final quote = data.quote(
          [const CartLine(sku: 'SKU001', qty: 10)],
          retailer.code,
          now: DateTime.parse('2026-11-07T03:00:00Z'),
        );
        await tester.pumpWidget(_host(
            Scaffold(
              body: OrderConfirmSheet(
                retailer: retailer,
                quote: quote,
                online: false,
                estimated: true,
              ),
            ),
            const [],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Xác nhận đơn hàng'), findsOneWidget);
        await _see(tester, find.text('Lưu bản nháp trên máy'));
        await _see(tester, find.text('Quay lại giỏ hàng'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
