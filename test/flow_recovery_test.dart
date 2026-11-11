import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaint_form_screen.dart';
import 'package:fscm_mobile/features/retailer/payments/payments_screen.dart';

void main() {
  test('new and legacy picking QR codes both open their order', () {
    expect(IdFormat.classify('PK-DH-001024-WH-HCM-01'),
        ScannedCodeKind.pickingList);
    expect(IdFormat.orderOfPickingList('PK-DH-001024-WH-HCM-01'), 'DH-001024');
    expect(IdFormat.classify('DH-001024A'), ScannedCodeKind.pickingList);
    expect(IdFormat.classify('PK-DH-001024-OTHER'), ScannedCodeKind.unknown);
  });
  test('complaint preserves the exact received shipment and allocation', () {
    final json = const NewComplaint(
            orderCode: 'DH-001024',
            sku: 'SKU001',
            labelCode: 'TEM-000001',
            actualQty: 3,
            issueType: 'Shortage',
            note: 'Missing one',
            shipmentId: 'shipment',
            allocationId: 'allocation')
        .toJson();
    expect(json['shipmentId'], 'shipment');
    expect(json['allocationId'], 'allocation');
    expect(json['actualQty'], 3);
  });
  testWidgets(
      'complaint order summary without lines still loads received batch targets',
      (tester) async {
    final order = Order.fromJson(
        {'id': 'order', 'orderCode': 'DH-001024', 'status': 'Delivering'});
    expect(order.lines, isEmpty);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          ordersProvider
              .overrideWith((ref) async => OrderListResult(orders: [order])),
          complaintTargetsProvider('order').overrideWith((ref) async => [
                const ComplaintTarget(
                    shipmentId: 'shipment',
                    shipmentCode: 'PH-001',
                    allocationId: 'allocation',
                    sku: 'SKU001',
                    productName: 'Sữa',
                    batchCode: 'BATCH-1',
                    labelCode: 'TEM-000001',
                    expectedQuantity: 4)
              ]),
        ],
        child: const MaterialApp(
            home: ComplaintFormScreen(orderCode: 'DH-001024'))));
    await tester.pumpAndSettle();
    expect(find.text('DH-001024'), findsOneWidget);
    await tester.tap(find.text('Sản phẩm · batch · phần giao'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SKU001 · BATCH-1 · PH-001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'payment totals use actual collections and remaining credit, separating prepaid',
      (tester) async {
    final rows = [
      Receivable.fromJson({
        'orderId': 'cancelled',
        'orderCode': 'DH-001004',
        'method': 'Credit',
        'status': 'Cancelled',
        'adjustedAmount': 500000,
        'confirmedAmount': 0,
        'outstandingAmount': 500000
      }),
      Receivable.fromJson({
        'orderId': 'credit',
        'orderCode': 'DH-001001',
        'method': 'Credit',
        'status': 'PartiallyPaid',
        'adjustedAmount': 100000,
        'confirmedAmount': 60000,
        'outstandingAmount': 40000
      }),
      Receivable.fromJson({
        'orderId': 'prepaid',
        'orderCode': 'DH-001002',
        'method': 'Prepaid',
        'status': 'Unpaid',
        'adjustedAmount': 90000,
        'confirmedAmount': 0,
        'outstandingAmount': 90000
      }),
      Receivable.fromJson({
        'orderId': 'paid',
        'orderCode': 'DH-001003',
        'method': 'Credit',
        'status': 'Paid',
        'adjustedAmount': 30000,
        'confirmedAmount': 30000,
        'outstandingAmount': 0
      }),
    ];
    await tester.pumpWidget(ProviderScope(
        overrides: [receivablesProvider.overrideWith((ref) async => rows)],
        child: const MaterialApp(home: PaymentsScreen())));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text(Money.format(90000)),
        findsWidgets); // Actual cash collected, and separate prepaid row.
    expect(find.text(Money.format(40000)), findsWidgets);
    expect(find.text(Money.format(130000)), findsNothing);
    expect(find.text('Đơn trả trước đang chờ thanh toán'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
