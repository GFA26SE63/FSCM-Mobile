import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';

// MOB-04: fields follow Backend OrderLineResult / OrderOrdinaryPromotionSnapshotResult.
// Line discountPercent = total (promotion + HSD) / gross; the promotion's own
// rate is ordinaryPromotion.discountPercent.
Map<String, dynamic> _line(
  String sku, {
  required int discount,
  required double totalPct,
  Map<String, dynamic>? promotion,
  bool shelfLife = false,
}) =>
    {
      'sku': sku,
      'productName': 'SP $sku',
      'quantity': 10,
      'unitPrice': 100000,
      'grossAmount': 1000000,
      'discountAmount': discount,
      'discountPercent': totalPct,
      'netAmount': 1000000 - discount,
      if (shelfLife) 'discountSourceType': 'ShelfLife',
      if (shelfLife) 'discountSourceCode': 'HSD-V2',
      if (promotion != null) 'ordinaryPromotion': promotion,
    };

Order _quote() => Order.fromJson({
      'id': 'q-1',
      'orderCode': 'DH-000001',
      'status': 'Quoted',
      'createdAt': '2026-11-20T10:00:00+07:00',
      'lines': [
        // 10% promotion (100,000) then 15% HSD on 900,000 (135,000) = 23.5%.
        _line('A',
            discount: 235000,
            totalPct: 23.5,
            shelfLife: true,
            promotion: {
              'promotionId': 'p-a',
              'code': 'KM-A',
              'name': 'KM Sữa A',
              'type': 'Campaign',
              'discountPercent': 10,
              'discountAmount': 100000,
            }),
        // Promotion only, 8%.
        _line('B', discount: 80000, totalPct: 8, promotion: {
          'promotionId': 'p-b',
          'name': 'KM Nước B',
          'type': 'Campaign',
          'discountPercent': 8,
          'discountAmount': 80000,
        }),
        // HSD only, no promotion.
        _line('C', discount: 150000, totalPct: 15, shelfLife: true),
        // Promotion snapshot without a rate (legacy/partial payload).
        _line('D', discount: 50000, totalPct: 5, promotion: {
          'promotionId': 'p-d',
          'name': 'KM Thiếu Tỷ Lệ',
          'discountAmount': 50000,
        }),
      ],
    });

void main() {
  test('promotion rate maps from ordinaryPromotion, not the line total', () {
    final lines = _quote().lines;
    expect(lines[0].promoPct, 10);
    expect(lines[0].discountPct, 23.5);
    expect(lines[1].promoPct, 8);
    expect(lines[2].promoPct, isNull);
    expect(lines[3].promoPct, isNull);
  });

  test('monetary values are unchanged and survive a cache round-trip', () {
    final order = _quote();
    expect(order.lines.map((l) => l.net), [765000, 920000, 850000, 950000]);
    expect(order.lines[0].campaignDiscount, 100000);
    expect(order.lines[0].shelfLifeDiscount, 135000);
    final restored = Order.fromJson(order.toJson());
    expect(restored.lines.map((l) => l.promoPct), [10, 8, null, null]);
    expect(restored.lines.map((l) => l.net), [765000, 920000, 850000, 950000]);
  });

  Future<void> pump(WidgetTester tester, Order order) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: OrderLinesCard(order)))));

  testWidgets('total discount shows as savings; promotion shows its own rate',
      (tester) async {
    await pump(tester, _quote());

    // Savings = persisted discountAmount, once per line (no duplicate −amount).
    expect(find.text('Tiết kiệm 235.000 VND'), findsOneWidget);
    expect(find.text('Tiết kiệm 80.000 VND'), findsOneWidget);
    expect(find.text('Tiết kiệm 150.000 VND'), findsOneWidget);
    expect(find.text('Tiết kiệm 50.000 VND'), findsOneWidget);
    expect(find.textContaining('−235.000 VND'), findsNothing);

    expect(find.text(' · KM 10%'), findsOneWidget);
    expect(find.text(' · KM 8%'), findsOneWidget);
    // Combined / HSD / total rates are never labelled as the promotion rate.
    expect(find.textContaining('23,5%'), findsNothing);
    expect(find.textContaining('23.5%'), findsNothing);
    expect(find.textContaining('KM 15%'), findsNothing);
    expect(find.textContaining('KM 5%'), findsNothing);

    // Name/rate pairing in the same row.
    Finder row(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
    expect(
        find.descendant(of: row('KM Sữa A'), matching: find.text(' · KM 10%')),
        findsOneWidget);
    expect(
        find.descendant(of: row('KM Nước B'), matching: find.text(' · KM 8%')),
        findsOneWidget);
    // HSD-only line keeps its HSD label without a promotion rate.
    expect(
        find.descendant(
            of: row('Giảm giá theo HSD'), matching: find.textContaining('KM ')),
        findsNothing);
    // Missing rate: name only.
    expect(find.text('KM Thiếu Tỷ Lệ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner example: 280 VND savings, Demo_Demo1 · KM 10%',
      (tester) async {
    final order = Order.fromJson({
      'id': 'q-2',
      'orderCode': 'DH-000002',
      'status': 'Quoted',
      'createdAt': '2026-11-20T10:00:00+07:00',
      'lines': [
        {
          'sku': 'X',
          'productName': 'SP X',
          'quantity': 5,
          'unitPrice': 240,
          'grossAmount': 1200,
          'discountAmount': 280,
          'discountPercent': 23.33,
          'netAmount': 920,
          'discountSourceType': 'ShelfLife',
          'discountSourceCode': 'HSD-V2',
          'ordinaryPromotion': {
            'promotionId': 'p-x',
            'name': 'Demo_Demo1',
            'type': 'Campaign',
            'discountPercent': 10,
            'discountAmount': 120,
          },
        },
      ],
    });
    await pump(tester, order);
    expect(find.text('Tiết kiệm 280 VND'), findsOneWidget);
    expect(find.text('Demo_Demo1'), findsOneWidget);
    expect(find.text(' · KM 10%'), findsOneWidget);
    expect(find.textContaining('23,33'), findsNothing);
    expect(find.textContaining('23.33'), findsNothing);
    expect(find.textContaining('−280 VND'), findsNothing);
    expect(order.lines.single.net, 920);
  });

  testWidgets('zero discount shows no savings or promotion label',
      (tester) async {
    await pump(
        tester,
        Order.fromJson({
          'id': 'q-3',
          'orderCode': 'DH-000003',
          'status': 'Quoted',
          'createdAt': '2026-11-20T10:00:00+07:00',
          'lines': [_line('Z', discount: 0, totalPct: 0)],
        }));
    expect(find.textContaining('Tiết kiệm'), findsNothing);
    expect(find.textContaining('KM '), findsNothing);
  });

  testWidgets('long promotion name keeps its rate visible on a 320px screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longName = 'Chương trình khuyến mãi cuối năm siêu dài dành cho '
        'toàn bộ nhóm sữa chua và nước cam khu vực miền Nam';
    await pump(
        tester,
        Order.fromJson({
          'id': 'q-4',
          'orderCode': 'DH-000004',
          'status': 'Quoted',
          'createdAt': '2026-11-20T10:00:00+07:00',
          'lines': [
            _line('L', discount: 125000, totalPct: 12.5, promotion: {
              'promotionId': 'p-l',
              'name': longName,
              'discountPercent': 12.5,
              'discountAmount': 125000,
            }),
          ],
        }));
    expect(find.text(' · KM 12,5%'), findsOneWidget);
    expect(
        tester.getRect(find.text(' · KM 12,5%')).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
