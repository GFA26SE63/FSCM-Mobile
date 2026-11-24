import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/label_detail.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';
import 'package:fscm_mobile/features/warehouse/home/wk_home_screen.dart';
import 'package:fscm_mobile/features/warehouse/labels/widgets/label_detail_content.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_detail_screen.dart';

/// UI.5 responsive checks for the WarehouseKeeper screens (360/390 dp,
/// 1.0/1.3/1.6 text scale). Camera widgets (`QrScanView`) are never mounted
/// here: the document screen keeps its scanner closed, so these tests cover the
/// presentation around the scanner only, not real scanning.
class _Transport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      const ApiResponse(statusCode: 200, data: <dynamic>[]);
}

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

const _keeper = AppUser(
    id: 'keeper',
    fullName: 'Nguyễn Văn Thủ Kho Phụ Trách Khu Vực Phía Đông',
    phone: '',
    role: UserRole.warehouseKeeper,
    warehouseIds: ['source', 'destination']);

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
      overrides: [
        currentUserProvider.overrideWithValue(_keeper),
        notificationsProvider.overrideWith((ref) => _FakeNotifications()),
        notificationBadgeProvider.overrideWith((ref) async => 0),
        ...overrides,
      ],
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

Future<void> _see(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
            of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first;
    try {
      await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
    } on StateError {
      // The row may sit above the current offset in the lazy list.
      await tester.scrollUntilVisible(target, -200, scrollable: scrollable);
    }
  }
  expect(target, findsOneWidget);
}

WarehouseWork _doc(String code,
        {String kind = 'Issue',
        String reason = 'Transfer',
        String status = 'Open',
        List<Map<String, dynamic>> cartons = const [],
        int qty = 987654}) =>
    WarehouseWork({
      'document': {
        'id': code,
        'code': code,
        'kind': kind,
        'reason': reason,
        'status': status,
        'warehouseId': 'source',
        'destinationWarehouseId': 'destination',
        'version': 3,
        'createdAt': '2026-11-20T08:00:00Z',
        'note': 'Ghi chú dài để kiểm tra việc xuống dòng trên màn hình nhỏ',
      },
      'lines': [
        {
          'sku': 'SKU-001',
          'productName': 'Sữa tươi tiệt trùng ít đường hộp giấy thùng 48 hộp',
          'batchCode': 'BATCH-2026-11-VERY-LONG-CODE',
          'expirationDate': '2026-12-31',
          'quantity': qty,
        }
      ],
      'cartons': cartons,
    });

ApiClient _client() =>
    ApiClient(transport: _Transport(), tokenReader: () => null);

void main() {
  for (final width in _widths) {
    for (final scale in _scales) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('home: summary, operations, documents, QR lookup kept ($tag)',
          (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            const WkHomeScreen(),
            [
              warehouseDocumentsProvider.overrideWith((ref) async => [
                    _doc('PXK-2026-11-000123-CODE-RAT-DAI'),
                    _doc('PNK-2026-11-000124', kind: 'Receipt'),
                  ]),
              factoryArrivalsProvider
                  .overrideWith((ref) async => <Map<String, dynamic>>[]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Cần xử lý'), findsOneWidget);
        for (final op in WarehouseOperation.values) {
          await _see(tester, find.text(op.title));
        }
        await _see(tester, find.text('PXK-2026-11-000123-CODE-RAT-DAI'));
        // Owner decision pending: the Baseline conflict button is still there.
        await _see(tester, find.text('Tra cứu QR'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('operations: grouped entry cards ($tag)', (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(
            _host(const WarehouseOperationsScreen(), const [], scale));
        await tester.pumpAndSettle();
        expect(find.text('Nhập kho'), findsOneWidget);
        for (final op in WarehouseOperation.values) {
          await _see(tester, find.text(op.title));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('document list: pending, arrivals, history toggle ($tag)',
          (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            const WarehouseDocumentsScreen(
                operation: WarehouseOperation.transferIssue),
            [
              warehouseDocumentsProvider.overrideWith((ref) async => [
                    _doc('PXK-2026-11-000123-CODE-RAT-DAI'),
                    _doc('PXK-DONE', status: 'Posted'),
                  ]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Cần xử lý'), findsOneWidget);
        expect(find.text('Lịch sử'), findsOneWidget);
        await _see(tester, find.text('PXK-2026-11-000123-CODE-RAT-DAI'));
        expect(find.text('PXK-DONE'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('factory receipt list shows pallet arrivals ($tag)',
          (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            const WarehouseDocumentsScreen(
                operation: WarehouseOperation.factoryReceipt),
            [
              warehouseDocumentsProvider
                  .overrideWith((ref) async => <WarehouseWork>[]),
              factoryArrivalsProvider.overrideWith((ref) async => [
                    {
                      'palletCode': 'PLT-2026-11-000001',
                      'sku': 'SKU-001',
                      'cartonCount': 480,
                      'destinationWarehouseId': 'destination',
                    }
                  ]),
            ],
            scale));
        await tester.pumpAndSettle();
        await _see(tester, find.text('PLT-2026-11-000001'));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'document detail: header, lines, progress, post action ($tag)',
          (tester) async {
        _phone(tester, width);
        final work = _doc('PXK-2026-11-000123-CODE-RAT-DAI', qty: 3, cartons: [
          {'cartonId': 'CTN-000001', 'scannedAt': '2026-11-20T09:00:00Z'},
          {'cartonId': 'CTN-000002', 'scannedAt': null},
          {'cartonId': 'CTN-000003', 'scannedAt': null},
        ]);
        await tester.pumpWidget(_host(
            const WarehouseDocumentScreen(id: 'doc1', mode: 'transferIssue'),
            [
              warehouseDocumentProvider('doc1')
                  .overrideWith((ref) async => work),
              warehouseDocumentsApiProvider
                  .overrideWith((ref) => WarehouseDocumentsApi(_client())),
            ],
            scale));
        await tester.pumpAndSettle();
        await _see(tester, find.text('Chờ thực hiện'));
        await _see(tester, find.text('Quét carton thực tế'));
        await _see(tester, find.text('Đã quét 1 / 3 thùng'));
        // M-20: API timestamp shows as dd/MM/yyyy HH:mm (Vietnam time).
        await _see(tester, find.text('20/11/2026 15:00'));
        final post = find.widgetWithText(
            FilledButton, 'Xác nhận xuất luân chuyển & ghi sổ PXK');
        await _see(tester, post);
        // Not all cartons scanned: posting stays disabled (rule unchanged).
        expect(tester.widget<FilledButton>(post).onPressed, isNull);
        expect(tester.takeException(), isNull);
      });

      testWidgets('posted document is read-only history ($tag)',
          (tester) async {
        _phone(tester, width);
        final work = _doc('PXK-DONE', status: 'Posted');
        await tester.pumpWidget(_host(
            const WarehouseDocumentScreen(id: 'doc2'),
            [
              warehouseDocumentProvider('doc2')
                  .overrideWith((ref) async => work),
              warehouseDocumentsApiProvider
                  .overrideWith((ref) => WarehouseDocumentsApi(_client())),
            ],
            scale));
        await tester.pumpAndSettle();
        await _see(tester, find.textContaining('lịch sử xuất/nhập'));
        expect(find.text('Quét carton thực tế'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('label detail content: header, links, history ($tag)',
          (tester) async {
        _phone(tester, width);
        Map<String, dynamic> label(String code, {String? parent}) => {
              'qrCode': code,
              'sku': 'SKU001',
              'productName':
                  'Sữa tươi tiệt trùng ít đường hộp giấy thùng 48 hộp',
              'batchCode': 'BATCH-2026-11-VERY-LONG-CODE',
              'warehouseCode': 'WH-THU-DUC-PHIA-DONG',
              'quantity': 987654,
              'status': 'Available',
              'version': 3,
              'expirationDate': '2026-12-01',
              'parentQrCode': parent,
              'rootQrCode': 'TEM-000001',
            };
        final detail = LabelDetail.fromJson({
          'label': label('TEM-000002', parent: 'TEM-000001'),
          'lineage': [
            label('TEM-000001'),
            label('TEM-000002', parent: 'TEM-000001'),
            label('TEM-000003', parent: 'TEM-000002'),
          ],
          'events': [
            {
              'id': 'e1',
              'eventType': 'Split',
              'quantity': 10,
              'occurredAt': '2026-11-06T02:00:00Z'
            }
          ],
        });
        await tester.pumpWidget(_host(
            Scaffold(body: LabelDetailContent(detail: detail)),
            const [],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('TEM-000002'), findsWidgets);
        await _see(tester, find.text('Lịch sử chuỗi tem'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('picking detail (notification link): header and lines ($tag)',
          (tester) async {
        _phone(tester, width);
        final list = PickingList.fromJson({
          'code': 'DH-001057A',
          'orderCode': 'DH-001057',
          'retailerCode': '10004127',
          'retailerName':
              'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé Quận Một',
          'status': 'Open',
          'warehouseName': 'Kho Thủ Đức phía Đông',
          'lines': [
            {
              'sku': 'SKU-001',
              'name': 'Sữa tươi tiệt trùng ít đường hộp giấy thùng 48 hộp',
              'batchCode': 'BATCH-2026-11-VERY-LONG-CODE',
              'need': 987654,
              'picked': 1,
              'suggestedLabel': 'TEM-000001',
            }
          ],
        });
        await tester.pumpWidget(_host(
            const PickingDetailScreen(code: 'DH-001057A'),
            [
              pickingDetailProvider('DH-001057A')
                  .overrideWith((ref) async => list)
            ],
            scale));
        await tester.pumpAndSettle();
        await _see(tester, find.text('Hoàn tất soạn hàng'));
        await _see(tester, find.text('Quét tem nguồn'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
