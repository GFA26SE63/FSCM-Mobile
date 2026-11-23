import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_orders_screen.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/quote_payment_sheet.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_quote_panel.dart';
import 'package:fscm_mobile/features/retailer/payments/payments_screen.dart';
import 'package:fscm_mobile/shared/widgets/payos_checkout_result_page.dart';

import 'fixtures/retailer_order_fixture.dart';

/// UI.4 responsive checks for Retailer screens: 360/390 dp x 1.0/1.3/1.6 text
/// scale, long Vietnamese text and large amounts. Providers are overridden with
/// fakes; nothing touches the real data layer.
class _FakeOrders extends StateNotifier<AsyncValue<RetailerOrdersState>>
    implements RetailerOrdersController {
  _FakeOrders(List<Order> orders)
      : super(AsyncData(RetailerOrdersState(
            orders: orders,
            totalCount: orders.length,
            page: 1,
            hasMore: false)));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

final _retailer = AppUser.fromJson(<String, dynamic>{
  'id': 'u1',
  'fullName': 'Cửa hàng An Phú',
  'email': 'an@example.com',
  'role': 'Retailer',
  'retailerCode': '10004127',
  'retailerName':
      'Cửa hàng tạp hóa Nguyễn Thị Minh Khai Phường Bến Nghé Quận Một',
  'scope': <String, dynamic>{},
});

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

Order _order({String status = 'Delivering'}) =>
    Order.fromJson(<String, dynamic>{
      'id': 'order-1',
      'orderCode': 'DH-001057-MÃ-ĐƠN-RẤT-DÀI-ĐỂ-THỬ-NGẮT-DÒNG',
      'retailerId': 'retailer-1',
      'retailerCode': '10004127',
      'retailerName': 'Cửa hàng',
      'status': status,
      'finalAmount': 987654321,
    });

void main() {
  for (final width in _widths) {
    for (final scale in _scales) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('orders home: header, to-do, filters, long order ($tag)',
          (tester) async {
        _phone(tester, width);
        final fake = _FakeOrders(<Order>[_order()]);
        await tester.pumpWidget(_host(
            const RtOrdersScreen(),
            [
              currentUserProvider.overrideWithValue(_retailer),
              retailerOrdersProvider.overrideWith((ref, search) => fake),
              retailerTodoProvider.overrideWith((ref) async =>
                  const RetailerTodo(
                      quotesToConfirm: 2,
                      paymentsPending: 1,
                      deliveriesToReceive: 1,
                      overdueCount: 1,
                      overdueAmount: 123456789,
                      dueSoonCount: 1,
                      dueSoonAmount: 9876543,
                      loyaltyPoints: 1200)),
              notificationsProvider.overrideWith((ref) => _FakeNotifications()),
              notificationBadgeProvider.overrideWith((ref) async => 0),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Đặt hàng'), findsOneWidget);
        expect(find.text('Đang xử lý'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Việc cần làm'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('quote panel: amount, deadline, both decisions ($tag)',
          (tester) async {
        _phone(tester, width);
        final order = retailerOrderFixture();
        await tester.pumpWidget(_host(
            Scaffold(
                body: SingleChildScrollView(
                    child: RetailerQuotePanel(order: order))),
            [
              orderQuotesProvider(order.id)
                  .overrideWith((ref) async => [retailerQuoteFixture()]),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.textContaining('Hạn phản hồi'), findsOneWidget);
        expect(find.text('Từ chối báo giá'), findsOneWidget);
        expect(find.text('Chấp nhận và chọn thanh toán'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('quote payment sheet: options and actions ($tag)',
          (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            Scaffold(
                body: QuotePaymentSheet(
                    order: retailerOrderFixture(),
                    quote: retailerQuoteFixture())),
            [
              retailerCreditProvider('retailer-1')
                  .overrideWith((ref) async => creditRetailerFixture(14)),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Trả trước'), findsOneWidget);
        expect(find.text('Công nợ'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Quay lại'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Quay lại'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('payments: summary, toolbar card and actions ($tag)',
          (tester) async {
        _phone(tester, width);
        final rows = <Receivable>[
          Receivable.fromJson(<String, dynamic>{
            'orderId': 'credit',
            'orderCode': 'DH-001001',
            'method': 'Credit',
            'status': 'PartiallyPaid',
            'adjustedAmount': 987654321,
            'confirmedAmount': 60000,
            'outstandingAmount': 987594321,
          }),
        ];
        await tester.pumpWidget(_host(
            const PaymentsScreen(),
            [
              receivablesProvider.overrideWith((ref) async => rows),
            ],
            scale));
        await tester.pumpAndSettle();
        expect(find.text('Công nợ có thể trả'), findsOneWidget);
        expect(find.text('Trả toàn bộ công nợ'), findsOneWidget);
        await _see(tester, find.text('DH-001001'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('PayOS result page: status, amount, actions ($tag)',
          (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(_host(
            PayOsCheckoutResultPage(
              checkoutUrl: 'https://example.test/pay',
              initial: const PayOsCheckoutSnapshot(
                  state: PayOsCheckoutState.pending,
                  amount: 987654321,
                  summary: 'Đơn DH-001057 và một số khoản công nợ khác'),
              refresh: () async => const PayOsCheckoutSnapshot(
                  state: PayOsCheckoutState.pending,
                  amount: 987654321,
                  summary: 'Đơn DH-001057'),
              homeRoute: '/',
              reviewRoute: '/',
              reviewLabel: 'Xem lại đơn hàng',
              openUrl: (_) async => true,
            ),
            const [],
            scale));
        await tester.pump();
        expect(find.text('Đang chờ PayOS xác nhận'), findsOneWidget);
        expect(find.text('Về trang chủ'), findsOneWidget);
        expect(find.text('Xem lại đơn hàng'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('payment method enum still has no COD option', () {
    expect(PaymentMethod.values.map((m) => m.name), isNot(contains('cod')));
  });
}
