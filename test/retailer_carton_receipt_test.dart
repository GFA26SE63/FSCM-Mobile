import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/receive/receive_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M-28: Retailer shipment receipt is by CARTON QR code (CID; TEM where the
/// label has that code). A batch code is never a carton; the Backend
/// (`ShipmentService.ConfirmReceiptAsync`) is the only judge of membership and
/// completeness. Camera decoding is NOT exercised: the manual-entry field
/// feeds the same `onCode` callback as the camera.
const _cid1 = 'CID-F01-20260827-A-0001-0001';
const _cid2 = 'CID-F01-20260827-A-0001-0002'; // same batch as _cid1
const _batchCode = 'WH-GV-SKU002-12102026';

class _Recorder implements ApiTransport {
  _Recorder(this.receiptReply);
  final ApiResponse Function() receiptReply;
  final List<ApiRequest> requests = <ApiRequest>[];

  List<ApiRequest> get receipts => [
        for (final r in requests)
          if (r.path.endsWith('/receipt')) r
      ];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.path.endsWith('/receipt')) return receiptReply();
    return const ApiResponse(statusCode: 500, data: <String, dynamic>{});
  }
}

const _user = AppUser(
    id: 'u1',
    fullName: 'Retailer',
    phone: '',
    role: UserRole.retailer,
    retailerCode: '1001');

DeliveryShipment _shipment() => DeliveryShipment.fromJson(<String, dynamic>{
      'id': 's1',
      'shipmentCode': 'GH-1',
      'warehouseCode': 'WH-A',
      'warehouseName': 'Kho A',
      'status': 'Delivering',
      'version': 5,
      'totalQuantity': 2.0,
      'receivedQuantity': 0,
      'lines': [
        {
          'orderLineId': 'line-1',
          'batchId': 'batch-1',
          'sku': 'SKU002',
          'batchCode': _batchCode,
          'quantity': 2.0,
        }
      ],
    });

Future<_Recorder> _pump(WidgetTester tester,
    {double width = 390,
    double scale = 1.0,
    ApiResponse Function()? receiptReply}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'device_code': 'TEST'});
  final name = 'carton_receipt_${DateTime.now().microsecondsSinceEpoch}.db';
  final database = AppDatabase(databaseName: name);
  final transport = _Recorder(receiptReply ??
      () => const ApiResponse(statusCode: 200, data: <String, dynamic>{}));
  final client = ApiClient(transport: transport, tokenReader: () => 'token');
  final repository = OrderRepository(
    api: OrdersApi(client),
    queue: OfflineOrderDao(database),
    syncState: SyncStateDao(database),
    device: DeviceIdentity(await SharedPreferences.getInstance()),
    ownerId: 'u1',
    isSales: false,
    isCurrentUser: () => true,
  );
  // The database is never opened here (the receipt does not touch it).
  addTearDown(client.dispose);
  final order = Order.fromJson(<String, dynamic>{
    'id': 'order-1',
    'orderCode': 'DH-001057',
    'status': 'Delivering',
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      orderRepositoryProvider.overrideWithValue(repository),
      orderDetailProvider('DH-001057').overrideWith((ref) async => order),
      deliveryShipmentsProvider('order-1')
          .overrideWith((ref) async => [_shipment()]),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: const RtReceiveScreen(code: 'DH-001057'),
    ),
  ));
  await tester.pumpAndSettle();
  return transport;
}

Future<void> _enter(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.widgetWithText(FilledButton, 'OK'));
  await tester.pumpAndSettle();
}

void main() {
  group('identifier rules', () {
    test('only carton codes pass; batch, pallet and unit codes are explained',
        () {
      expect(IdFormat.cartonScanError(_cid1), isNull);
      expect(IdFormat.cartonScanError('TEM-000187'), isNull);
      expect(IdFormat.cartonScanError(_batchCode), contains('mã lô hàng'));
      expect(IdFormat.cartonScanError('PID-F01-20260827-A-0001-0001'),
          contains('mã pallet'));
      expect(IdFormat.cartonScanError('UID-F01-20260827-A-0001-000001'),
          contains('mã sản phẩm'));
      expect(IdFormat.cartonScanError('hello'), contains('Không nhận diện'));
      expect(IdFormat.cartonScanError('CID-F01-20260827-A-0001'),
          contains('Không nhận diện'));
    });
  });

  for (final width in <double>[360, 390]) {
    for (final scale in <double>[1.0, 1.3, 1.6]) {
      testWidgets('carton wording and counter fit (${width.toInt()}dp x$scale)',
          (tester) async {
        await _pump(tester, width: width, scale: scale);
        expect(find.textContaining('Quét mã thùng (CID)'), findsOneWidget);
        expect(find.textContaining('Phần giao này có 2 thùng'), findsOneWidget);
        expect(find.text('Quét mã QR trên thùng hàng'), findsOneWidget);
        expect(find.text('Số thùng đã quét (0)'), findsOneWidget);
        expect(find.textContaining('tem'), findsNothing);
        await _enter(tester, _cid1);
        expect(find.text('Số thùng đã quét (1)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('batch / pallet / garbage codes are rejected with a reason',
      (tester) async {
    await _pump(tester);
    for (final bad in [
      _batchCode,
      'PID-F01-20260827-A-0001-0001',
      'khong-phai-ma'
    ]) {
      await _enter(tester, bad);
    }
    expect(find.text('Số thùng đã quét (0)'), findsOneWidget);
    await _enter(tester, _batchCode);
    expect(find.textContaining('mã lô hàng'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Xác nhận phần giao WH-A'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận phần giao WH-A'))
            .onPressed,
        isNull);
  });

  testWidgets('CIDs of one batch count individually; duplicates do not',
      (tester) async {
    await _pump(tester);
    await _enter(tester, '  ${_cid1.toLowerCase()} ');
    await _enter(tester, _cid2);
    expect(find.text('Số thùng đã quét (2)'), findsOneWidget);
    await _enter(tester, _cid1);
    expect(find.textContaining('đã được quét'), findsOneWidget);
    expect(find.text('Số thùng đã quét (2)'), findsOneWidget);
  });

  testWidgets('confirm sends exactly the scanned CIDs once (contract payload)',
      (tester) async {
    final t = await _pump(tester);
    await _enter(tester, _cid1);
    await _enter(tester, _cid2);
    await tester
        .tap(find.widgetWithText(FilledButton, 'Xác nhận phần giao WH-A'));
    await tester.pumpAndSettle();

    expect(t.receipts, hasLength(1));
    final r = t.receipts.single;
    expect(r.path, '/shipments/s1/receipt');
    expect(r.headers['Idempotency-Key'], isNotEmpty);
    final body = r.body! as Map<String, dynamic>;
    expect(body['qrCodes'], [_cid1, _cid2]);
    expect(body['expectedVersion'], 5);
    expect(body['lines'], [
      {
        'orderLineId': 'line-1',
        'batchId': 'batch-1', // contract key of the shipment line, not scanned
        'receivedQuantity': 2.0,
        'damagedQuantity': 0,
      }
    ]);
    // A scan is never a batch id.
    expect(
        (body['qrCodes'] as List).any((c) => IdFormat.isBatch('$c')), isFalse);
  });

  testWidgets(
      'Backend rejection is explained in Vietnamese; scans are kept; '
      'no retry', (tester) async {
    final t = await _pump(tester,
        receiptReply: () =>
            const ApiResponse(statusCode: 400, data: <String, dynamic>{
              'title': 'Validation failed',
              'detail':
                  'Receipt must scan every QR label dispatched for this shipment exactly once.'
            }));
    await _enter(tester, _cid1);
    await tester
        .tap(find.widgetWithText(FilledButton, 'Xác nhận phần giao WH-A'));
    await tester.pumpAndSettle();

    expect(t.receipts, hasLength(1)); // no automatic retry
    expect(find.textContaining('Chưa quét đủ hoặc có mã không thuộc phần giao'),
        findsOneWidget);
    expect(find.text('Số thùng đã quét (1)'), findsOneWidget); // can scan more
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Xác nhận phần giao WH-A'))
            .onPressed,
        isNotNull);
    expect(find.text('Đã xác nhận một phần giao của DH-001057'), findsNothing);
  });
}
