import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/warehouse/home/wk_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';

class RecordingTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return ApiResponse(
        statusCode: 200,
        data: request.path.endsWith('/pallet-scans')
            ? {
                'id': 'scan',
                'palletCode': 'PID-1',
                'documentVersion': 7,
                'manifest': {'cartons': []}
              }
            : {
                'document': {'id': 'receipt', 'version': 8},
                'lines': [],
                'cartons': []
              });
  }
}

void main() {
  const keeper = AppUser(
      id: 'keeper',
      fullName: 'Thủ kho',
      phone: '',
      role: UserRole.warehouseKeeper,
      warehouseIds: ['source', 'destination']);
  WarehouseWork issue(String state) => WarehouseWork({
        'document': {
          'id': 'draft',
          'code': 'PXK-DRAFT',
          'kind': 'Issue',
          'reason': 'Transfer',
          'status': state,
          'warehouseId': 'source',
          'destinationWarehouseId': 'destination',
          'version': 1
        },
        'lines': [
          {'sku': 'SKU', 'productName': 'Sữa', 'quantity': 1}
        ],
        'cartons': []
      });
  for (final state in ['Open', 'Posted']) {
    testWidgets('issue $state only offers scanning while the PXK is pending',
        (tester) async {
      final t = RecordingTransport();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => keeper),
            warehouseDocumentProvider('draft')
                .overrideWith((ref) async => issue(state)),
            warehouseDocumentsApiProvider.overrideWith((ref) =>
                WarehouseDocumentsApi(
                    ApiClient(transport: t, tokenReader: () => null))),
          ],
          child: const MaterialApp(
              home: WarehouseDocumentScreen(
                  id: 'draft', mode: 'transferIssue'))));
      await tester.pumpAndSettle();
      expect(find.text('Quét carton thực tế'),
          state == 'Open' ? findsOneWidget : findsNothing);
      expect(find.text('Mở phiếu nhập luân chuyển'), findsNothing);
      if (state == 'Open') {
        final button = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận xuất luân chuyển & ghi sổ PXK'));
        expect(button.onPressed, isNull);
      }
      expect(t.requests.where((r) => r.method == 'POST'), isEmpty);
    });
  }
  testWidgets('home lists only pending documents and no legacy picking lists',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWith((ref) => keeper),
      warehouseDocumentsProvider.overrideWith((ref) async {
        final open = issue('Open');
        open.document['sourceDocumentId'] = 'parent';
        final done = issue('Posted');
        done.document['code'] = 'PXK-HISTORY';
        return [
          open,
          done,
          WarehouseWork({
            'document': {
              'id': 'parent',
              'code': 'YCK-HIDDEN',
              'kind': 'Request',
              'reason': 'Transfer',
              'status': 'Open',
              'warehouseId': 'source'
            }
          })
        ];
      }),
      factoryArrivalsProvider
          .overrideWith((ref) async => <Map<String, dynamic>>[]),
    ], child: const MaterialApp(home: WkHomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Picking list cần lấy'), findsNothing);
    expect(find.text('PXK-DRAFT'), findsOneWidget);
    expect(find.text('PXK-HISTORY'), findsNothing);
    expect(find.text('YCK-HIDDEN'), findsNothing);
    for (final op in WarehouseOperation.values) {
      expect(find.text(op.title), findsOneWidget);
    }
  });

  test(
      'factory scan records camera signal without sending receipt confirmation',
      () async {
    final transport = RecordingTransport();
    final api = WarehouseDocumentsApi(
        ApiClient(transport: transport, tokenReader: () => null));
    final work = WarehouseWork({
      'document': {'id': 'receipt', 'version': 6}
    });
    final scan = await api.scanPallet(work, 'PID-1');
    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.path,
        '/warehouse-documents/receipt/pallet-scans');
    expect(transport.requests.single.body,
        {'code': 'PID-1', 'expectedVersion': 6, 'source': 'Camera'});
    final cartons = <Map<String, dynamic>>[
      {'cartonCode': 'CID-1', 'disposition': 'Accepted'}
    ];
    await api.confirmPallet(work, scan, cartons);
    expect(transport.requests.last.path,
        '/warehouse-documents/receipt/receive-pallet');
    expect(transport.requests.last.body, {
      'palletCode': 'PID-1',
      'scanId': 'scan',
      'expectedVersion': 7,
      'cartons': cartons
    });
  });
  test('transfer scans and posting remain separate versioned requests',
      () async {
    final t = RecordingTransport();
    final api =
        WarehouseDocumentsApi(ApiClient(transport: t, tokenReader: () => null));
    final work = WarehouseWork({
      'document': {'id': 'inbound', 'version': 3}
    });
    await api.scanCarton(work, 'CID-2');
    expect(t.requests.single.path, '/warehouse-documents/inbound/scans');
    expect(t.requests.single.body, {'cartonId': 'CID-2', 'expectedVersion': 3});
    await api.post(work);
    expect(t.requests.last.path, '/warehouse-documents/inbound/post');
  });
  test('the four operations distinguish transfer receipts from transfer issues',
      () {
    expect(
        WarehouseOperation.transferReceipt
            .includes({'reason': 'Transfer', 'kind': 'Receipt'}),
        isTrue);
    expect(
        WarehouseOperation.transferIssue
            .includes({'reason': 'Transfer', 'kind': 'Receipt'}),
        isFalse);
    expect(
        WarehouseOperation.transferIssue
            .includes({'reason': 'Transfer', 'kind': 'Picking'}),
        isTrue);
    expect(
        WarehouseOperation.factoryReceipt
            .includes({'reason': 'Transfer', 'kind': 'Receipt'}),
        isFalse);
  });
  testWidgets('four warehouse entry points fit a phone and navigate separately',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/wk/operations', routes: [
      GoRoute(
          path: '/wk/operations',
          builder: (_, __) => const WarehouseOperationsScreen()),
      GoRoute(
          path: '/wk/documents/:operation',
          builder: (_, s) => Scaffold(
              body: Text('Selected ${s.pathParameters['operation']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final operation in WarehouseOperation.values) {
      await tester.pumpAndSettle();
      expect(find.text(operation.title), findsOneWidget);
      await tester.tap(find.text(operation.title));
      await tester.pumpAndSettle();
      expect(find.text('Selected ${operation.name}'), findsOneWidget);
      router.pop();
    }
    expect(tester.takeException(), isNull);
  });
}
