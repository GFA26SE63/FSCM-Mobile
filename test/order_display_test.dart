import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';

const _skuName = 'DEMO 08-11 · SKU sữa chua giảm 16%';
const _groupName = 'DEMO 08-11 · Nhóm sữa chua và nước cam giảm 14%';

Order _demoOrder() => Order.fromJson({
      'id': 'demo-1065',
      'orderCode': 'DH-001065',
      'status': 'Completed',
      'createdAt': '2026-11-08T18:57:41.975308+07:00',
      'lines': [
        {
          'sku': 'SKU002',
          'quantity': 10,
          'unitPrice': 320000,
          'discountAmount': 646400,
          'discountSourceType': 'ShelfLife',
          'discountSourceCode': 'HSD-V2',
          'ordinaryPromotion': {
            'promotionId': 'campaign-8',
            'name': _skuName,
            'discountAmount': 512000
          }
        },
        {
          'sku': 'SKU005',
          'quantity': 10,
          'unitPrice': 325000,
          'discountAmount': 594750,
          'discountSourceType': 'ShelfLife',
          'discountSourceCode': 'HSD-V2',
          'ordinaryPromotion': {
            'promotionId': 'campaign-9',
            'name': _groupName,
            'discountAmount': 455000
          }
        },
      ],
    });

void main() {
  test('timestamps display in Vietnam for equivalent UTC and offset inputs',
      () {
    for (final value in [
      '2026-11-08T11:57:41Z',
      '2026-11-08T18:57:41+07:00',
      '2026-11-08T06:57:41-05:00'
    ]) {
      final time = DateTime.parse(value);
      expect(AppDates.timeDay(time), '18:57 08/11');
      expect(AppDates.time(time), '18:57');
    }
    expect(AppDates.timeDay(DateTime.utc(2026, 11, 8, 19, 30)), '02:30 09/11');
    expect(AppDates.date(DateTime.utc(2026, 11, 8, 19, 30)), '09/11/2026');
    expect(AppDates.date(DateTime.parse('2026-11-22')), '22/11/2026');
    expect(AppDates.dayMonth(DateTime.parse('2026-11-14')), '14/11');
    expect(AppDates.timeDay(null), '—');
  });

  test('campaign names and shared HSD stay distinct with exact demo amounts',
      () {
    final order = _demoOrder();
    final promos = order.appliedPromos;
    expect(
        promos.map((p) => p.name), [_skuName, _groupName, 'Giảm giá theo HSD']);
    expect(promos.map((p) => p.amount), [512000, 455000, 274150]);
    expect(promos.last.detail, contains('SKU002 × 10'));
    expect(promos.last.detail, contains('SKU005 × 10'));
    expect(promos.fold<int>(0, (sum, p) => sum + p.amount), 1241150);
    expect(order.lines.fold<int>(0, (sum, l) => sum + l.net), 5208850);
  });

  test(
      'cache round trip preserves timestamp zone, date-only expiry and discount components',
      () {
    final original = _demoOrder();
    final json = original.toJson();
    expect(json['createdAt'], endsWith('Z'));
    final restored = Order.fromJson(json);
    expect(AppDates.timeDay(restored.createdAt), '18:57 08/11');
    expect(restored.appliedPromos.map((p) => p.name),
        original.appliedPromos.map((p) => p.name));
    expect(
        restored.appliedPromos.map((p) => p.amount), [512000, 455000, 274150]);
    final allocation = BatchAllocation.fromJson({
      'batchCode': 'B1',
      'quantity': 10,
      'batchExpirationDate': '2026-11-14'
    });
    expect(AppDates.date(BatchAllocation.fromJson(allocation.toJson()).expiry),
        '14/11/2026');
  });

  test(
      'pure shelf-life, campaign-only and legacy discounts are not lost or duplicated',
      () {
    final order = Order.fromJson({
      'lines': [
        {
          'sku': 'A',
          'quantity': 1,
          'unitPrice': 100,
          'discountAmount': 5,
          'discountSourceType': 'ShelfLife',
          'discountSourceCode': 'HSD-V2'
        },
        {
          'sku': 'B',
          'quantity': 1,
          'unitPrice': 100,
          'discountAmount': 10,
          'ordinaryPromotion': {
            'promotionId': 'p',
            'name': 'Ưu đãi số lượng',
            'discountAmount': 10
          }
        },
        {
          'sku': 'C',
          'quantity': 1,
          'unitPrice': 100,
          'discount': 10,
          'promoId': 'p',
          'promoName': 'Ưu đãi số lượng'
        },
      ]
    });
    expect(order.appliedPromos.map((p) => p.name),
        ['Ưu đãi số lượng', 'Giảm giá theo HSD']);
    expect(order.appliedPromos.map((p) => p.amount), [20, 5]);
    expect(Order.fromJson(order.toJson()).appliedPromos.map((p) => p.amount),
        [20, 5]);
  });

  testWidgets(
      'long campaign names and component totals fit a narrow mobile screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: AppliedPromoCard(_demoOrder().appliedPromos),
    ))));
    expect(find.text(_skuName), findsOneWidget);
    expect(find.text(_groupName), findsOneWidget);
    expect(find.text('Giảm giá theo HSD'), findsOneWidget);
    expect(find.text('Khuyến mãi và giảm giá HSD'), findsNothing);
    expect(find.textContaining('campaign-'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
