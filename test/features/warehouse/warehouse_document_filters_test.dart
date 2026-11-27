import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';

// MOB-02: GET /warehouse-documents returns the keeper's whole scope (Backend
// WarehouseWorkService.ListAsync has no paging), so device filtering is exact.

const _keeper = AppUser(
    id: 'k',
    fullName: 'Thủ kho',
    phone: '',
    role: UserRole.warehouseKeeper,
    warehouseIds: ['A', 'B']);

WarehouseWork _doc(String id, String code, String status, String warehouse,
        [String createdAt = '2026-11-20T03:00:00Z']) =>
    WarehouseWork({
      'document': {
        'id': id,
        'code': code,
        'kind': 'Issue',
        'reason': 'Order',
        'status': status,
        'warehouseId': warehouse,
        'version': 1,
        'createdAt': createdAt
      },
      'lines': [
        {'sku': 'SKU', 'productName': 'Sữa', 'quantity': 1}
      ],
      'cartons': <Object>[],
    });

final _docs = [
  _doc('1', 'PXK-A-001', 'Open', 'A'),
  _doc('2', 'PXK-A-002', 'Prepared', 'A'),
  _doc('3', 'PXK-B-003', 'Open', 'B'),
  _doc('4', 'PXK-C-004', 'Open', 'C'), // outside scope
];

Future<List<String>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => const WarehouseDocumentsScreen(
            operation: WarehouseOperation.orderIssue)),
    GoRoute(
        path: '/wk/document/:id',
        builder: (_, s) {
          opened.add(s.uri.toString());
          return const Text('DETAIL');
        }),
  ]);
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserProvider.overrideWith((ref) => _keeper),
    warehouseDocumentsProvider.overrideWith((ref) async => _docs),
  ], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _pick(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test('filters by code, status and warehouse, alone and combined', () {
    List<String> codes(WarehouseDocumentFilter f) =>
        filterWarehouseWorks(_docs.take(3).toList(), f)
            .map((w) => w.document['code'] as String)
            .toList();
    expect(codes(const WarehouseDocumentFilter(search: ' a-00')),
        ['PXK-A-001', 'PXK-A-002']);
    expect(codes(const WarehouseDocumentFilter(status: 'Open')),
        ['PXK-A-001', 'PXK-B-003']);
    expect(
        codes(const WarehouseDocumentFilter(warehouseId: 'B')), ['PXK-B-003']);
    expect(
        codes(const WarehouseDocumentFilter(
            search: 'pxk', status: 'Open', warehouseId: 'A')),
        ['PXK-A-001']);
    expect(codes(const WarehouseDocumentFilter(search: 'zzz')), isEmpty);
    expect(codes(const WarehouseDocumentFilter()).length, 3);
  });

  testWidgets('search, status, warehouse, reset and open after filtering',
      (tester) async {
    final opened = await _pump(tester);
    // Scope: C is never listed.
    expect(find.text('PXK-C-004'), findsNothing);
    expect(find.text('PXK-A-001'), findsOneWidget);
    expect(find.text('PXK-B-003'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('wk-doc-search')), 'B-003');
    await tester.pumpAndSettle();
    expect(find.text('PXK-A-001'), findsNothing);
    expect(find.text('PXK-B-003'), findsOneWidget);
    expect(find.text('1/3 chứng từ'), findsOneWidget);

    await tester.tap(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('PXK-A-001'), findsOneWidget);
    expect(find.text('Xóa bộ lọc'), findsNothing);

    // Vietnamese status labels, not enum values.
    await _pick(tester, 'wk-doc-status', 'Đã soạn đủ');
    expect(find.text('PXK-A-002'), findsOneWidget);
    expect(find.text('PXK-A-001'), findsNothing);
    expect(find.text('Prepared'), findsNothing);

    await _pick(tester, 'wk-doc-warehouse', 'B');
    expect(find.text('Không có chứng từ khớp bộ lọc.'), findsOneWidget);

    await _pick(tester, 'wk-doc-status', 'Tất cả');
    expect(find.text('PXK-B-003'), findsOneWidget);
    expect(find.text('PXK-A-001'), findsNothing);

    await tester.tap(find.text('PXK-B-003'));
    await tester.pumpAndSettle();
    expect(opened, ['/wk/document/3?mode=orderIssue']);
  });

  test('date range is inclusive by local day and combines with other filters',
      () {
    final docs = [
      _doc(
          'd1', 'PXK-1', 'Open', 'A', '2026-11-19T16:59:00Z'), // 19/11 23:59 VN
      _doc(
          'd2', 'PXK-2', 'Open', 'A', '2026-11-19T17:00:00Z'), // 20/11 00:00 VN
      _doc('d3', 'PXK-3', 'Posted', 'A', '2026-11-22T10:00:00Z'),
      _doc('d4', 'PXK-4', 'Open', 'B', '2026-11-25T10:00:00Z'),
      _doc('d5', 'PXK-5', 'Open', 'A', 'not-a-date'),
    ];
    List<String> codes(WarehouseDocumentFilter f) =>
        filterWarehouseWorks(docs, f)
            .map((w) => w.document['code'] as String)
            .toList();
    final range = DateTimeRange(
        start: DateTime(2026, 11, 20), end: DateTime(2026, 11, 22));
    // Local-day boundaries depend on the test machine time zone; compute them.
    bool inRange(String iso) {
      final d = DateTime.parse(iso).toLocal();
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(range.start) && !day.isAfter(range.end);
    }

    expect(codes(WarehouseDocumentFilter(dates: range)), [
      for (final (code, iso) in [
        ('PXK-1', '2026-11-19T16:59:00Z'),
        ('PXK-2', '2026-11-19T17:00:00Z'),
        ('PXK-3', '2026-11-22T10:00:00Z'),
        ('PXK-4', '2026-11-25T10:00:00Z'),
      ])
        if (inRange(iso)) code
    ]);
    expect(codes(WarehouseDocumentFilter(dates: range, status: 'Posted')),
        ['PXK-3']);
    expect(
        codes(WarehouseDocumentFilter(
            dates: DateTimeRange(
                start: DateTime(2026, 11, 25), end: DateTime(2026, 11, 25)),
            warehouseId: 'A')),
        isEmpty);
    expect(WarehouseDocumentFilter(dates: range).isEmpty, isFalse);
  });

  testWidgets('date button opens the range picker', (tester) async {
    await _pump(tester);
    expect(find.text('Ngày lập: tất cả'), findsOneWidget);
    // Flutter's own range picker overflows 22px at 400px with the wide test
    // font (also without any app code); use a wider test view for it.
    tester.view.physicalSize = const Size(800, 1600);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wk-doc-dates')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });
}
