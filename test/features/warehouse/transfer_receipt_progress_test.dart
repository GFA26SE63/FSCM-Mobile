import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';

// MOB-06. Backend (read-only): receipt-reports / pallet-scans check access on
// the document's own WarehouseId (the SOURCE warehouse for a transfer issue),
// answering 403 "Kho không thuộc phạm vi quản lý." to a destination keeper.
// A transfer receipt is a child document whose cartons are copied WITHOUT
// ScannedAt, so receipt progress starts at 0.

class _Transport implements ApiTransport {
  _Transport({this.forbidHistoryFor});
  final String? forbidHistoryFor;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest r) async {
    requests.add(r);
    if (forbidHistoryFor != null && r.path.contains('/$forbidHistoryFor/')) {
      return const ApiResponse(
          statusCode: 403,
          data: {'detail': 'Kho không thuộc phạm vi quản lý.'});
    }
    return const ApiResponse(statusCode: 200, data: <Object>[]);
  }

  Iterable<String> get paths => requests.map((r) => '${r.method} ${r.path}');
}

AppUser _keeper(List<String> warehouses) => AppUser(
    id: 'k',
    fullName: 'Thủ kho',
    phone: '',
    role: UserRole.warehouseKeeper,
    warehouseIds: warehouses);

/// Source transfer issue: WH-A → WH-B, 1 carton already scanned and posted by A.
WarehouseWork _sourceIssue() => WarehouseWork({
      'document': {
        'id': 'issue',
        'code': 'PXK-1',
        'kind': 'Issue',
        'reason': 'Transfer',
        'status': 'Posted',
        'warehouseId': 'A',
        'destinationWarehouseId': 'B',
        'version': 5
      },
      'lines': [
        {'sku': 'SKU', 'productName': 'Sữa', 'quantity': 1}
      ],
      'cartons': [
        {'cartonId': 'CID-1', 'scannedAt': '2026-11-20T01:00:00Z'}
      ],
    });

WarehouseWork _receipt(
        {String status = 'Open', List<String> scanned = const []}) =>
    WarehouseWork({
      'document': {
        'id': 'receipt',
        'code': 'PNK-1',
        'kind': 'Receipt',
        'reason': 'Transfer',
        'status': status,
        'warehouseId': 'B',
        'destinationWarehouseId': 'B',
        'sourceDocumentId': 'issue',
        'version': 1
      },
      'lines': [
        {'sku': 'SKU', 'productName': 'Sữa', 'quantity': 2}
      ],
      'cartons': [
        for (final id in ['CID-1', 'CID-2'])
          {
            'cartonId': id,
            'scannedAt': scanned.contains(id) ? '2026-11-21T01:00:00Z' : null
          }
      ],
    });

Future<_Transport> _open(WidgetTester tester,
    {required AppUser user,
    required String id,
    required Future<WarehouseWork> Function() doc,
    String mode = 'transferReceipt',
    String? forbidHistoryFor}) async {
  final t = _Transport(forbidHistoryFor: forbidHistoryFor);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserProvider.overrideWith((ref) => user),
    warehouseDocumentProvider(id).overrideWith((ref) => doc()),
    warehouseDocumentsApiProvider.overrideWith((ref) => WarehouseDocumentsApi(
        ApiClient(transport: t, tokenReader: () => null))),
  ], child: MaterialApp(home: WarehouseDocumentScreen(id: id, mode: mode))));
  await tester.pumpAndSettle();
  return t;
}

void main() {
  test('receiving context needs a posted transfer issue into the keeper scope',
      () {
    final d = _sourceIssue().document;
    expect(isIncomingTransfer('transferReceipt', d, ['B']), isTrue);
    expect(isIncomingTransfer('transferReceipt', d, ['A', 'B']), isTrue);
    expect(isIncomingTransfer('transferReceipt', d, ['A']), isFalse);
    expect(isIncomingTransfer('transferReceipt', d, ['C']), isFalse);
    expect(isIncomingTransfer('transferIssue', d, ['B']), isFalse);
    expect(isIncomingTransfer('transferReceipt', _receipt().document, ['B']),
        isFalse);
  });

  testWidgets('destination keeper: no scope error, no source progress',
      (tester) async {
    final t = await _open(tester,
        user: _keeper(['B']),
        id: 'issue',
        doc: () async => _sourceIssue(),
        forbidHistoryFor: 'issue');
    expect(find.textContaining('không thuộc phạm vi'), findsNothing);
    expect(find.text('Tiến độ quét'), findsNothing);
    expect(find.textContaining('1 / 1'), findsNothing);
    expect(find.text('Bắt đầu kiểm nhận & quét QR'), findsOneWidget);
    expect(t.paths.where((p) => p.contains('receipt-reports')), isEmpty);
    expect(t.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('keeper of both warehouses does not see the issue 1/1 as receipt',
      (tester) async {
    final t = await _open(tester,
        user: _keeper(['A', 'B']),
        id: 'issue',
        doc: () async => _sourceIssue());
    expect(find.text('Tiến độ quét'), findsNothing);
    expect(find.textContaining('Đã quét 1 / 1'), findsNothing);
    expect(find.text('CID-1'), findsNothing);
    expect(find.textContaining('Phiếu đã ghi sổ'), findsNothing);
    expect(find.text('Bắt đầu kiểm nhận & quét QR'), findsOneWidget);
    expect(t.paths.where((p) => p.contains('receipt-reports')), isEmpty);
  });

  testWidgets('source keeper viewing its own posted issue keeps its history',
      (tester) async {
    final t = await _open(tester,
        user: _keeper(['A']),
        id: 'issue',
        doc: () async => _sourceIssue(),
        mode: 'transferIssue');
    expect(find.textContaining('Đã quét 1 / 1'), findsOneWidget);
    expect(find.text('Bắt đầu kiểm nhận & quét QR'), findsNothing);
    expect(t.paths.where((p) => p.contains('receipt-reports')), isNotEmpty);
  });

  testWidgets('unauthorized keeper gets no receiving action', (tester) async {
    await _open(tester,
        user: _keeper(['C']), id: 'issue', doc: () async => _sourceIssue());
    expect(find.text('Bắt đầu kiểm nhận & quét QR'), findsNothing);
    expect(find.text('Tiến độ quét'), findsNothing);
  });

  testWidgets('new receipt starts at 0 scanned and cannot be posted',
      (tester) async {
    final t = await _open(tester,
        user: _keeper(['B']), id: 'receipt', doc: () async => _receipt());
    expect(find.text('Đã quét 0 / 2 thùng'), findsOneWidget);
    expect(find.textContaining('hoàn tất'), findsNothing);
    final post = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận nhập kho & ghi sổ PNK'));
    expect(post.onPressed, isNull);
    expect(t.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('partial receipt counts only persisted scans', (tester) async {
    await _open(tester,
        user: _keeper(['B']),
        id: 'receipt',
        doc: () async => _receipt(scanned: ['CID-1']));
    expect(find.text('Đã quét 1 / 2 thùng'), findsOneWidget);
    final post = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận nhập kho & ghi sổ PNK'));
    expect(post.onPressed, isNull);
  });

  testWidgets('reopened fully-scanned receipt is postable but not auto-posted',
      (tester) async {
    final t = await _open(tester,
        user: _keeper(['B']),
        id: 'receipt',
        doc: () async => _receipt(scanned: ['CID-1', 'CID-2']));
    expect(find.text('Đã quét 2 / 2 thùng'), findsOneWidget);
    expect(find.textContaining('Phiếu đã ghi sổ'), findsNothing);
    final post = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận nhập kho & ghi sổ PNK'));
    expect(post.onPressed, isNotNull);
    expect(t.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('confirmed receipt is read-only history', (tester) async {
    await _open(tester,
        user: _keeper(['B']),
        id: 'receipt',
        doc: () async =>
            _receipt(status: 'Posted', scanned: ['CID-1', 'CID-2']));
    expect(find.textContaining('Phiếu đã ghi sổ'), findsOneWidget);
    expect(find.text('Xác nhận nhập kho & ghi sổ PNK'), findsNothing);
    expect(find.text('Quét carton thực tế'), findsNothing);
  });

  testWidgets('backend authorization failure is shown, not hidden',
      (tester) async {
    await _open(tester,
        user: _keeper(['B']),
        id: 'receipt',
        doc: () async => throw const ApiException(
            message: 'Phiếu không thuộc kho bạn quản lý.',
            kind: ApiErrorKind.forbidden,
            statusCode: 403));
    expect(find.textContaining('Phiếu không thuộc kho bạn quản lý'),
        findsOneWidget);
  });
}
