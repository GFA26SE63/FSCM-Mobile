import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';
import 'package:fscm_mobile/features/sales/declare/declarations_screen.dart';
import 'package:fscm_mobile/features/sales/products/promotions_screen.dart';
import 'package:fscm_mobile/features/sales/sync/sync_queue_screen.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

/// UI.7D: dd/MM/yyyy dates (M-20), draft tabs (M-13), promotion filter
/// (M-14), declaration chips (M-17).
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

void _phone(WidgetTester tester, double width, {double height = 720}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
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

RetailerDeclaration _declaration(int i, String status, String name) =>
    RetailerDeclaration.fromJson(<String, dynamic>{
      'id': 'r-$i',
      'code': 'KB-010$i',
      'name': name,
      'status': status,
      'retailerType': 'ConvenienceStore',
      'storeSizeCategory': 'M',
      'potentialClass': 'B',
      'purchaseFrequencyPerMonth': 8,
    });

void main() {
  group('M-20 dates are dd/MM/yyyy', () {
    test('date-only values keep the calendar day (leading zeros, leap year)',
        () {
      expect(AppDates.date(DateTime.parse('2026-01-05')), '05/01/2026');
      expect(AppDates.date(DateTime.parse('2028-02-29')), '29/02/2028');
      expect(AppDates.date(DateTime.parse('2026-12-31')), '31/12/2026');
      expect(AppDates.date(null), '—');
    });

    test('timestamps show Vietnam time as dd/MM/yyyy HH:mm', () {
      expect(AppDates.timeDay(DateTime.utc(2026, 11, 8, 11, 57)),
          '08/11/2026 18:57');
      // Year boundary: 18:00Z on 31 Dec is 01:00 on 1 Jan in Vietnam.
      expect(
          AppDates.timeDay(DateTime.utc(2026, 12, 31, 18)), '01/01/2027 01:00');
      expect(AppDates.timeDay(null), '—');
    });

    test('text from the API is parsed, never guessed; bad text is kept', () {
      expect(AppDates.dateText('2026-01-05'), '05/01/2026');
      expect(AppDates.dateText('2026-11-20T08:00:00Z'), '20/11/2026');
      expect(AppDates.dateTimeText('2026-11-20T08:00:00Z'), '20/11/2026 15:00');
      // Ambiguous US-style text is not parsed as a date: shown as received.
      expect(AppDates.dateText('11/22/2026'), '11/22/2026');
      expect(AppDates.dateText(null), '—');
      expect(AppDates.dateText(''), '—');
      // The payload format is unchanged.
      expect(AppDates.isoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  for (final width in <double>[360, 390]) {
    for (final scale in <double>[1.0, 1.3, 1.6]) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('M-13 draft tabs start at the content edge ($tag)',
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
        final first = tester.getTopLeft(find.textContaining('Cần xử lý ('));
        // Not indented by the 52 dp Material 3 offset.
        expect(first.dx, lessThan(40));
        expect(find.textContaining('Đang gửi ('), findsOneWidget);
        expect(find.textContaining('Kết quả ('), findsOneWidget);
        await tester.tap(find.textContaining('Kết quả ('));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'M-14 promotion filter keeps its text inside the field ($tag)',
          (tester) async {
        _phone(tester, width);
        final json = mobileSnapshotFixture();
        final retailers =
            (json['retailers'] as List).cast<Map<String, dynamic>>();
        retailers.first['name'] =
            'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé Quận Một';
        final data = CatalogData.fromSnapshot(SyncSnapshot.fromJson(json));
        await tester.pumpWidget(_host(
            const PromotionsScreen(),
            [
              networkMonitorProvider.overrideWith((ref) => _FakeNetwork()),
              catalogProvider.overrideWith((ref) async => data),
            ],
            scale));
        await tester.pumpAndSettle();
        final field =
            tester.getRect(find.byType(DropdownButtonFormField<String>));
        final selected = tester.getRect(
            find.text('Tất cả chương trình trong dữ liệu đồng bộ').first);
        expect(selected.left, greaterThanOrEqualTo(field.left));
        expect(selected.right, lessThanOrEqualTo(field.right));
        expect(selected.bottom, lessThanOrEqualTo(field.bottom));

        // Open the menu, choose the long retailer name: selection stays inside.
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Cửa hàng tạp hóa').last);
        await tester.pumpAndSettle();
        final field2 =
            tester.getRect(find.byType(DropdownButtonFormField<String>));
        final chosen =
            tester.getRect(find.textContaining('Cửa hàng tạp hóa').first);
        expect(chosen.right, lessThanOrEqualTo(field2.right));
        expect(tester.takeException(), isNull);
      });

      testWidgets('M-17 declaration cards: chip always at the right ($tag)',
          (tester) async {
        _phone(tester, width, height: 4000);
        const long = 'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé';
        final rows = <RetailerDeclaration>[
          _declaration(1, 'Draft', 'An'),
          _declaration(2, 'PendingApproval', long),
          _declaration(3, 'Active', 'Bình Minh'),
          _declaration(4, 'Rejected', long),
          _declaration(5, 'Inactive', 'Cô Ba'),
        ];
        await tester.pumpWidget(_host(const DeclarationsScreen(),
            [declarationsProvider.overrideWith((ref) async => rows)], scale));
        await tester.pumpAndSettle();

        final chips = find.byType(StatusChip);
        expect(chips, findsNWidgets(5));
        final rights = [
          for (var i = 0; i < 5; i++) tester.getRect(chips.at(i)).right
        ];
        // Same right edge for every card, short names and long names alike.
        for (final r in rights) {
          expect(r, closeTo(rights.first, 0.5));
        }
        // And on the same line as the name (not wrapped below it).
        final nameTop = tester.getTopLeft(find.textContaining('KB-0102')).dy;
        final chipTop = tester.getTopLeft(chips.at(1)).dy;
        expect((chipTop - nameTop).abs(), lessThan(12));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
