import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/shell/retailer_shell.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaint_form_screen.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaints_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/gifts_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/loyalty_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/widgets/gift_redeem_sheet.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_order_detail_screen.dart';
import 'package:fscm_mobile/features/retailer/receive/receive_screen.dart';
import 'package:go_router/go_router.dart';

import 'fixtures/loyalty_fixture.dart';

/// UI.4B responsive checks for the Retailer areas UI.4 left uncovered.
/// Providers are overridden with fake data; QR camera behaviour is NOT tested
/// here (only the screens around it).
const _user = AppUser(
    id: 'user-1',
    fullName: 'Retailer',
    phone: '',
    role: UserRole.retailer,
    retailerCode: '1001');

const _widths = <double>[360, 390];
const _scales = <double>[1.0, 1.3, 1.6];

void _phone(WidgetTester tester, double width, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 720);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Widget _host(Widget home, List<Override> overrides, double scale) =>
    ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(_user), ...overrides],
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
    await tester.scrollUntilVisible(target, 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
  }
  expect(target, findsOneWidget);
}

Order _order(String status) => Order.fromJson(<String, dynamic>{
      'id': 'order-1',
      'orderCode': 'DH-001057',
      'retailerId': 'retailer-1',
      'retailerCode': '10004127',
      'retailerName':
          'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé Quận Một',
      'status': status,
      'finalAmount': 987654321,
    });

LoyaltyAccount _card({int balance = 500}) => LoyaltyAccount.fromJson(
    loyaltyCardFixture(balance: balance, ledger: [
      loyaltyLedgerFixture(points: 987654, id: 'tx-1'),
      loyaltyLedgerFixture(
          type: 'Redeemed', points: -200, id: 'tx-2', redemptionId: 'red-1'),
    ]),
    program: LoyaltyProgram.fromJson(
        {...loyaltyProgramFixture(), 'isActive': true}));

Gift _gift(String id, int points, {int? stock = 5}) =>
    Gift.fromJson(<String, dynamic>{
      'id': id,
      'code': 'QUA-$id',
      'name': 'Quà tặng có tên rất dài để kiểm tra việc xuống dòng $id',
      'loyaltyProgramId': 'program-1',
      'requiredPoints': points,
      'availableQuantity': stock,
      'isActive': true,
      'description':
          'Mô tả quà tặng khá dài để kiểm tra bố cục trên điện thoại',
      'imageUrl': null,
    });

void main() {
  for (final width in _widths) {
    for (final scale in _scales) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('order detail: header, shipments, actions ($tag)',
          (tester) async {
        _phone(tester, width);
        final order = _order('Delivered');
        await tester.pumpWidget(_host(
            const RtOrderDetailScreen(code: 'DH-001057'),
            [
              orderDetailProvider('DH-001057')
                  .overrideWith((ref) async => order),
              deliveryShipmentsProvider('order-1').overrideWith((ref) async => [
                    DeliveryShipment.fromJson(<String, dynamic>{
                      'id': 's1',
                      'shipmentCode': 'GH-1',
                      'warehouseName': 'Kho trung chuyển Thủ Đức phía Đông',
                      'status': 'Received',
                      'totalQuantity': 10,
                      'receivedQuantity': 10,
                    }),
                  ]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('DH-001057'), findsWidgets);
        await _see(tester, find.text('Tạo yêu cầu theo đơn'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('loyalty: gold hero, history rows, program card ($tag)',
          (tester) async {
        _phone(tester, width);
        final card = _card();
        await tester.pumpWidget(_host(
            const LoyaltyScreen(),
            [
              loyaltyAccountProvider.overrideWith((ref) async => card),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('điểm khả dụng'), findsOneWidget);
        await _see(tester, find.text('Đổi quà'));
        // The program card now sits right under the balance, above the history.
        await _see(tester, find.text('Chương trình tích điểm'));
        await _see(tester, find.text('Lịch sử điểm'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('gifts: catalogue states and requests ($tag)',
          (tester) async {
        _phone(tester, width);
        final card = _card(balance: 150);
        await tester.pumpWidget(_host(
            const GiftsScreen(),
            [
              loyaltyAccountProvider.overrideWith((ref) async => card),
              giftsProvider.overrideWith((ref) async => [
                    _gift('1', 100),
                    _gift('2', 100000, stock: 3),
                    _gift('3', 100, stock: 0),
                  ]),
              redemptionsProvider
                  .overrideWith((ref) async => const <GiftRedemption>[]),
              pendingRedemptionProvider.overrideWith((ref) async => null),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Điểm khả dụng'), findsOneWidget);
        await _see(tester, find.text('Thiếu điểm'));
        await _see(tester, find.text('Hết quà'));
        await _see(tester, find.text('Chưa có yêu cầu đổi quà.'));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'redeem sheet: summary, stepper, actions with keyboard ($tag)',
          (tester) async {
        _phone(tester, width, keyboard: 280);
        await tester.pumpWidget(_host(
            Scaffold(
                body: GiftRedeemSheet(gift: _gift('1', 100), balance: 987654)),
            const [],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Gửi yêu cầu đổi quà'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Hủy'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Hủy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('complaints list: long text, banners, actions ($tag)',
          (tester) async {
        _phone(tester, width);
        final complaint = Complaint.fromJson(<String, dynamic>{
          'id': 'c1',
          'requestCode': 'YC-001',
          'status': 'Open',
          'reviewStatus': 'UnderReview',
          'requestType': 'Complaint',
          'orderCode': 'DH-001057',
          'sku': 'SKU001',
          'productName': 'Sữa tươi tiệt trùng ít đường hộp giấy thùng 48 hộp',
          'requestedQuantity': 3,
          'note': 'Hàng bị móp méo nhiều hộp khi giao đến cửa hàng của tôi',
          'evidenceRequestReason':
              'Vui lòng gửi thêm ảnh chụp mặt trước và mặt sau của thùng hàng',
          'response': 'Chúng tôi đã tiếp nhận yêu cầu và sẽ phản hồi sớm',
        });
        await tester.pumpWidget(_host(
            const ComplaintsScreen(),
            [
              complaintsProvider.overrideWith((ref) async => [complaint]),
              complaintEvidenceProvider('c1')
                  .overrideWith((ref) async => const <ComplaintEvidence>[]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Tạo yêu cầu'), findsOneWidget);
        await _see(tester, find.textContaining('Yêu cầu bổ sung'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in _widths) {
    for (final scale in <double>[1.3, 1.6]) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('complaint form: sections reachable with keyboard ($tag)',
          (tester) async {
        // 1.6x text with a 300dp keyboard leaves ~420dp of viewport, too small
        // for the dropdown overlay in the harness; use a smaller inset there.
        _phone(tester, width, keyboard: scale > 1.5 ? 140 : 300);
        final order = Order.fromJson(
            {'id': 'order', 'orderCode': 'DH-1', 'status': 'Delivered'});
        await tester.pumpWidget(_host(
            const ComplaintFormScreen(orderCode: 'DH-1'),
            [
              ordersProvider.overrideWith(
                  (ref) async => OrderListResult(orders: [order])),
              complaintTargetsProvider('order').overrideWith((ref) async => [
                    const ComplaintTarget(
                        shipmentId: 'shipment',
                        shipmentCode: 'PH-1',
                        allocationId: 'allocation',
                        sku: 'SKU001',
                        productName: 'Sữa tươi tiệt trùng ít đường hộp giấy',
                        batchCode: 'BATCH-1',
                        labelCode: 'TEM-1',
                        expectedQuantity: 10,
                        receivedQuantity: 8,
                        remainingClaimableQuantity: 6,
                        remainingReturnableQuantity: 3)
                  ]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Thông tin yêu cầu'), findsOneWidget);
        await _see(tester, find.text('Sản phẩm · lô hàng · phần giao'));
        await tester.ensureVisible(find.text('Sản phẩm · lô hàng · phần giao'));
        await tester.tap(find.text('Sản phẩm · lô hàng · phần giao'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('SKU001 · BATCH-1 · PH-1').last);
        await tester.pumpAndSettle();
        await _see(tester, find.text('Ảnh bằng chứng'));
        await _see(tester, find.text('Gửi yêu cầu'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('receive screen: not-ready order shows message and back action',
      (tester) async {
    _phone(tester, 360);
    final order = _order('Quoted');
    await tester.pumpWidget(_host(
        const RtReceiveScreen(code: 'DH-001057'),
        [
          orderDetailProvider('DH-001057').overrideWith((ref) async => order),
        ],
        1.6));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa thể xác nhận nhận hàng'), findsOneWidget);
    expect(find.text('Quay lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('receive screen: no shipment to confirm shows the banner',
      (tester) async {
    _phone(tester, 390);
    final order = _order('Delivering');
    await tester.pumpWidget(_host(
        const RtReceiveScreen(code: 'DH-001057'),
        [
          orderDetailProvider('DH-001057').overrideWith((ref) async => order),
          deliveryShipmentsProvider('order-1')
              .overrideWith((ref) async => const <DeliveryShipment>[]),
        ],
        1.3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có phần giao nào'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('retailer navbar', () {
    Future<GoRouter> pump(WidgetTester tester) async {
      final paths = <String>['/o', '/q', '/a'];
      final router = GoRouter(initialLocation: '/o', routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, s) => RetailerShell(navigationShell: s),
          branches: [
            for (final p in paths)
              StatefulShellBranch(routes: [
                GoRoute(
                    path: p,
                    builder: (_, __) => Scaffold(body: Text('Page $p')))
              ]),
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp.router(
              theme: buildAppTheme(), routerConfig: router)));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets(
        'QR destination keeps 3 tabs, one icon, emphasised circle inside the bar and tappable',
        (tester) async {
      await pump(tester);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      final bar = tester.getRect(find.byType(NavigationBar));
      final circle = tester.getRect(find
          .ancestor(
              of: find.byIcon(Icons.qr_code_scanner),
              matching: find.byType(DecoratedBox))
          .first);
      // The whole circle stays inside the bar so every part of it is tappable.
      expect(circle.top, greaterThanOrEqualTo(bar.top));
      expect(circle.bottom, lessThanOrEqualTo(bar.bottom));
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pumpAndSettle();
      expect(find.text('Page /q'), findsOneWidget);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1);
    });
  });
}
