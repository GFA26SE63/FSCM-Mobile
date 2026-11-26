import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';
import 'package:fscm_mobile/features/warehouse/home/wk_home_screen.dart';

/// Minimal stateful server for request → issue → scan → post (Backend
/// WarehouseWorkService semantics: post marks issue Posted, request Fulfilled).
class _Server implements ApiTransport {
  final docs = <String, Map<String, dynamic>>{
    'req': {
      'id': 'req', 'code': 'LDC-1', 'kind': 'Request', 'reason': 'Transfer',
      'status': 'Open', 'warehouseId': 'A', 'destinationWarehouseId': 'B',
      'version': 1
    },
  };
  final cartons = <String, List<Map<String, dynamic>>>{'req': []};
  final lines = [
    {'sku': 'SKU', 'productName': 'Sữa', 'quantity': 1}
  ];

  Map<String, dynamic> work(String id) =>
      {'document': docs[id], 'lines': lines, 'cartons': cartons[id]};

  final log = <String>[];

  @override
  Future<ApiResponse> send(ApiRequest r) async {
    final p = r.path;
    log.add('${r.method} $p');
    if (r.method == 'GET' && p == '/warehouse-documents') {
      return ApiResponse(
          statusCode: 200, data: [for (final id in docs.keys) work(id)]);
    }
    if (p.endsWith('/factory-pending')) {
      return const ApiResponse(statusCode: 200, data: <Object>[]);
    }
    if (p.endsWith('/receipt-reports') || p.endsWith('/pallet-scans')) {
      return const ApiResponse(statusCode: 200, data: <Object>[]);
    }
    if (p.endsWith('/create-document')) {
      docs['iss'] = {
        'id': 'iss', 'code': 'PXK-1', 'kind': 'Issue', 'reason': 'Transfer',
        'status': 'Open', 'warehouseId': 'A', 'destinationWarehouseId': 'B',
        'sourceDocumentId': 'req', 'version': 1
      };
      cartons['iss'] = [];
      return ApiResponse(statusCode: 200, data: work('iss'));
    }
    if (p.endsWith('/scans')) {
      cartons['iss']!.add({'cartonId': 'CID-1', 'scannedAt': '2026-11-26'});
      docs['iss']!['version'] = 2;
      return ApiResponse(statusCode: 200, data: work('iss'));
    }
    if (p.endsWith('/post')) {
      docs['iss']!['status'] = 'Posted';
      docs['req']!['status'] = 'Fulfilled';
      return ApiResponse(statusCode: 200, data: work('iss'));
    }
    final id = p.split('/').last;
    return ApiResponse(statusCode: 200, data: work(id));
  }
}

void main() {
  testWidgets('back after posting a transfer issue never shows it unscanned',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = _Server();
    final router = GoRouter(initialLocation: '/list', routes: [
      GoRoute(
          path: '/list',
          builder: (_, __) => const WarehouseDocumentsScreen(
              operation: WarehouseOperation.transferIssue)),
      GoRoute(
          path: '/wk/document/:id',
          builder: (_, s) => WarehouseDocumentScreen(
              id: s.pathParameters['id']!,
              mode: s.uri.queryParameters['mode'])),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWith((ref) => const AppUser(
          id: 'k',
          fullName: 'Thủ kho',
          phone: '',
          role: UserRole.warehouseKeeper,
          warehouseIds: ['A'])),
      warehouseDocumentsApiProvider.overrideWith((ref) => WarehouseDocumentsApi(
          ApiClient(transport: server, tokenReader: () => null))),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LDC-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu xuất luân chuyển & quét QR'));
    await tester.pumpAndSettle();
    expect(find.text('PXK-1'), findsOneWidget);

    // Scan (camera stand-in): the server records the carton.
    await tester.runAsync(() => WarehouseDocumentsApi(
            ApiClient(transport: server, tokenReader: () => null))
        .scanCarton(WarehouseWork(server.work('iss')), 'CID-1'));
    final element = tester.element(find.byType(WarehouseDocumentScreen));
    ProviderScope.containerOf(element)
        .invalidate(warehouseDocumentProvider('iss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận xuất luân chuyển & ghi sổ PXK'));
    await tester.pumpAndSettle();
    expect(find.text('Đã ghi sổ'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    // Back lands on the list; the posted issue and fulfilled request are no
    // longer offered as work to scan.
    expect(find.byType(WarehouseDocumentsScreen), findsOneWidget);
    expect(find.text('Bắt đầu xuất luân chuyển & quét QR'), findsNothing);
    expect(find.text('Quét carton thực tế'), findsNothing);
    expect(find.text('PXK-1'), findsNothing);
    expect(find.text('LDC-1'), findsNothing);
  });

  testWidgets('from keeper Home (shell): back after posting shows fresh state',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = _Server();
    // Same shape as lib/app/router.dart: Home inside a StatefulShellRoute,
    // the document route at top level.
    final router = GoRouter(initialLocation: '/wk', routes: [
      GoRoute(
          path: '/wk/document/:id',
          builder: (_, s) => WarehouseDocumentScreen(
              id: s.pathParameters['id']!,
              mode: s.uri.queryParameters['mode'],
              autoScan: s.uri.queryParameters['scan'] == '1')),
      StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/wk', builder: (_, __) => const WkHomeScreen()),
            ]),
          ]),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWith((ref) => const AppUser(
          id: 'k',
          fullName: 'Thủ kho',
          phone: '',
          role: UserRole.warehouseKeeper,
          warehouseIds: ['A'])),
      warehouseDocumentsApiProvider.overrideWith((ref) => WarehouseDocumentsApi(
          ApiClient(transport: server, tokenReader: () => null))),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LDC-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu xuất luân chuyển & quét QR'));
    await tester.pumpAndSettle();
    expect(find.text('PXK-1'), findsOneWidget);

    await tester.runAsync(() => WarehouseDocumentsApi(
            ApiClient(transport: server, tokenReader: () => null))
        .scanCarton(WarehouseWork(server.work('iss')), 'CID-1'));
    ProviderScope.containerOf(
            tester.element(find.byType(WarehouseDocumentScreen)))
        .invalidate(warehouseDocumentProvider('iss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận xuất luân chuyển & ghi sổ PXK'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WarehouseDocumentScreen), findsNothing);
    expect(find.byType(WkHomeScreen), findsOneWidget);
    expect(find.text('LDC-1'), findsNothing);
    expect(find.text('PXK-1'), findsNothing);
  });

  testWidgets('request copy left under the issue is refreshed after posting',
      (tester) async {
    // Device log: a Home card tap pushed the request twice; pushReplacement
    // replaced only the top copy, the lower one kept "Chờ thực hiện · 0/1".
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = _Server();
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const SizedBox()),
      GoRoute(
          path: '/wk/document/:id',
          builder: (_, s) => WarehouseDocumentScreen(
              id: s.pathParameters['id']!,
              mode: s.uri.queryParameters['mode'])),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWith((ref) => const AppUser(
          id: 'k',
          fullName: 'Thủ kho',
          phone: '',
          role: UserRole.warehouseKeeper,
          warehouseIds: ['A'])),
      warehouseDocumentsApiProvider.overrideWith((ref) => WarehouseDocumentsApi(
          ApiClient(transport: server, tokenReader: () => null))),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    unawaited(router.push('/wk/document/req'));
    unawaited(router.push('/wk/document/req?tap=2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bắt đầu xuất luân chuyển & quét QR'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => WarehouseDocumentsApi(
            ApiClient(transport: server, tokenReader: () => null))
        .scanCarton(WarehouseWork(server.work('iss')), 'CID-1'));
    ProviderScope.containerOf(
            tester.element(find.byType(WarehouseDocumentScreen).last))
        .invalidate(warehouseDocumentProvider('iss'));
    await tester.pumpAndSettle();
    final postAt = server.log.length;
    await tester.tap(find.text('Xác nhận xuất luân chuyển & ghi sổ PXK'));
    await tester.pumpAndSettle();
    // Posting re-reads the request still on the back stack.
    expect(server.log.skip(postAt), contains('GET /warehouse-documents/req'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('LDC-1'), findsOneWidget);
    expect(find.text('Chờ thực hiện'), findsNothing);
    expect(find.text('Đã thực hiện'), findsWidgets);
    expect(find.text('Bắt đầu xuất luân chuyển & quét QR'), findsNothing);
  });
}
