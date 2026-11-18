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
