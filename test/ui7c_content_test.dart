import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/numbers.dart';
import 'package:fscm_mobile/core/utils/status_labels.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_delivery_progress.dart';
import 'package:fscm_mobile/features/retailer/payments/payments_screen.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';

/// UI.7C: Vietnamese statuses/errors, debt-payment wording, quantity format.
final _vietnamese = RegExp(r'[^\x00-\x7F]');

void main() {
  group('M-19 formatQuantity (display only)', () {
    test('integral, fractional, zero, negative and large values', () {
      expect(formatQuantity(0), '0');
      expect(formatQuantity(1.0), '1');
      expect(formatQuantity(10), '10');
      expect(formatQuantity(2.5), '2,5');
      expect(formatQuantity(0.1 + 0.2), '0,3'); // no float noise
      expect(formatQuantity(1234), '1.234');
      expect(formatQuantity(1234.5), '1.234,5');
      expect(formatQuantity(987654321.0), '987.654.321');
      expect(formatQuantity(-3.0), '−3');
      expect(formatQuantity(-0.0001), '0'); // never "−0"
      expect(formatQuantity(double.nan), '0');
    });

    test('non-numbers pass through unchanged', () {
      expect(formatQuantity('abc'), 'abc');
      expect(formatQuantity(null), '');
    });
  });

  group('M-03 statuses are Vietnamese', () {
    test('allocation state and result mappings', () {
      for (final v in ['Allocating', 'Allocated', 'Failed', 'NotApplicable']) {
        expect(allocationStateLabel(v), matches(_vietnamese), reason: v);
      }
      for (final v in ['Pending', 'Fulfilled', 'Short', 'Allocated']) {
        expect(allocationResultLabel(v), matches(_vietnamese), reason: v);
      }
      expect(allocationStateLabel('Allocating'), 'Đang phân bổ hàng');
      expect(allocationResultLabel('Short'), 'Thiếu hàng');
      // Unknown values never leak raw English.
      expect(allocationStateLabel('Whatever'), unknownStatusLabel);
      expect(allocationResultLabel(null), unknownStatusLabel);
    });

    test('shipment and warehouse document fallbacks are not raw codes', () {
      DeliveryShipment shipment(String status) =>
          DeliveryShipment.fromJson({'id': 's', 'status': status});
      expect(shipment('Delivering').statusLabel, 'Đang giao');
      expect(shipment('Exception').statusLabel, 'Có sự cố giao hàng');
      expect(shipment('SomethingNew').statusLabel, unknownStatusLabel);
      expect(warehouseStatus('Posted'), 'Đã ghi sổ');
      expect(warehouseStatus('Odd'), unknownStatusLabel);
    });
  });

  group('M-10 errors are Vietnamese', () {
    test('English server text is localized, original kept in details', () {
      final e = ApiException.fromProblem(409, <String, dynamic>{
        'detail': 'There is no collectible receivable to pay.'
      });
      expect(
          e.message, 'Không có khoản công nợ nào có thể thanh toán lúc này.');
      expect(e.details, contains('collectible'));
      expect(e.statusCode, 409);
      expect(e.kind, ApiErrorKind.conflict);
    });

    test('unknown English text falls back to the message of its kind', () {
      final v = ApiException.fromProblem(
          400, <String, dynamic>{'title': 'Validation failed'});
      expect(v.message, 'Dữ liệu không hợp lệ.');
      expect(v.title, 'Validation failed');
      final s = ApiException.fromProblem(
          500, <String, dynamic>{'detail': 'Internal server error'});
      expect(s.message, matches(_vietnamese));
    });

    test('Vietnamese server text is untouched; raw exceptions are not shown',
        () {
      final e = ApiException.fromProblem(
          409, <String, dynamic>{'detail': 'Tem đã được quét.'});
      expect(e.message, 'Tem đã được quét.');
      expect(e.details, isNull);
      final shown = ApiException.describe(StateError('internal stack text'));
      expect(shown, isNot(contains('StateError')));
      expect(shown, isNot(contains('internal')));
      expect(shown, matches(_vietnamese));
    });
  });

  testWidgets('M-19 delivery progress shows 10 / 30 thùng for 10.0 / 30.0',
      (tester) async {
    final order = Order.fromJson({'id': 'order-1', 'status': 'Delivering'});
    final shipment = DeliveryShipment.fromJson({
      'id': 's1',
      'shipmentCode': 'GH-1',
      'warehouseName': 'Kho A',
      'status': 'Delivering',
      'totalQuantity': 30.0,
      'receivedQuantity': 10.0,
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          deliveryShipmentsProvider('order-1')
              .overrideWith((ref) async => [shipment]),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: RetailerDeliveryProgress(order: order))))));
    await tester.pumpAndSettle();
    expect(find.text('10 / 30 thùng'), findsOneWidget);
  });

  group('M-04 / M-05 debt payment', () {
    final rows = <Receivable>[
      Receivable.fromJson(<String, dynamic>{
        'id': 'payment-1',
        'orderId': 'order-1',
        'orderCode': 'DH-001001-MÃ-ĐƠN-RẤT-DÀI',
        'status': 'Unpaid',
        'adjustedAmount': 987654321,
        'outstandingAmount': 987654321,
        'collectibleAmount': 987654321,
        'dueDate': '2030-01-01T00:00:00Z',
      }),
    ];

    for (final width in <double>[360, 390]) {
      for (final scale in <double>[1.0, 1.3, 1.6]) {
        testWidgets('labels and actions fit (${width.toInt()}dp x$scale)',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 720);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(ProviderScope(
            overrides: [receivablesProvider.overrideWith((ref) async => rows)],
            child: MaterialApp(
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const PaymentsScreen(),
            ),
          ));
          await tester.pumpAndSettle();

          expect(find.text('Công nợ có thể trả'), findsOneWidget);
          expect(find.text('Các khoản đã chọn'), findsOneWidget);
          final some =
              find.widgetWithText(OutlinedButton, 'Trả các khoản đã chọn');
          final all = find.widgetWithText(FilledButton, 'Trả toàn bộ công nợ');
          expect(some, findsOneWidget);
          expect(all, findsOneWidget);
          // Nothing ticked: only "all" can start; callbacks keep their rules.
          expect(tester.widget<OutlinedButton>(some).onPressed, isNull);
          expect(tester.widget<FilledButton>(all).onPressed, isNotNull);
          // Old wording is gone.
          expect(find.text('Thanh toán hết'), findsNothing);
          expect(find.text('Thanh toán một phần'), findsNothing);

          // "All" only opens a confirmation; the payment starts on PayOS.
          await tester.tap(all);
          await tester.pumpAndSettle();
          expect(find.text('Xác nhận trả toàn bộ công nợ'), findsOneWidget);
          expect(find.text('Thanh toán với PayOS'), findsOneWidget);
          expect(find.textContaining('chuyển sang PayOS'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
