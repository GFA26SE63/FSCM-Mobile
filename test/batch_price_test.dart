import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/shared/widgets/batch_price_breakdown.dart';

Map<String, dynamic> _fragment(String batch, int qty, double finalPrice) => {
      'batchCode': batch,
      'warehouseCode': 'WH-HCM',
      'quantity': qty,
      'batchExpirationDate': '2026-12-20',
      'listUnitPrice': 320000,
      'ordinaryPromotionDiscountPerUnit': 32000,
      'baseUnitPrice': 288000,
      'remainingShelfLifePercent': 62.5,
      'shelfLifeDiscountPerUnit': 28800,
      'finalUnitPrice': finalPrice,
      'netAmount': finalPrice * qty,
      'discountReason': 'HSD còn 62,5%',
      'weightedScore': 0.91,
      'distanceMeters': 1200,
    };

void main() {
  test('allocation fragments keep the server price snapshot per batch', () {
    final line = OrderLine.fromJson({
      'sku': 'SKU002',
      'productName': 'Sữa chua',
      'quantity': 10,
      'unitPrice': 320000,
      'allocationFragments': [
        _fragment('B1', 6, 259200),
        _fragment('B2', 4, 259200),
      ],
    });

    expect(line.batches.length, 2);
    final first = line.batches.first;
    expect(first.hasPriceSnapshot, isTrue);
    expect(first.finalUnitPrice, 259200);
    expect(first.netAmount, 259200 * 6);
    expect(first.remainingShelfLifePercent, 62.5);
    expect(first.shelfLifeDiscountPercent, closeTo(10, 0.001));
    // Internal allocation data must not leak into the model.
    expect(first.toJson().containsKey('weightedScore'), isFalse);
    expect(first.toJson().containsKey('distanceMeters'), isFalse);
  });

  test('old orders without a snapshot are marked and never repriced', () {
    final line = OrderLine.fromJson({
      'sku': 'SKU001',
      'quantity': 3,
      'unitPrice': 100000,
      'allocations': [
        {'batchCode': 'B9', 'quantity': 3, 'warehouseCode': 'WH-HN'},
      ],
    });

    expect(line.batches.single.hasPriceSnapshot, isFalse);
    expect(line.batches.single.finalUnitPrice, 0);
  });

  testWidgets('breakdown shows one block per batch and a note when no snapshot',
      (tester) async {
    final priced = OrderLine.fromJson({
      'sku': 'SKU002',
      'quantity': 10,
      'unitPrice': 320000,
      'allocationFragments': [
        _fragment('B1', 6, 259200),
        _fragment('B2', 4, 259200),
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BatchPriceBreakdown(batches: priced.batches)),
    ));
    expect(find.textContaining('B1 · 6 thùng'), findsOneWidget);
    expect(find.textContaining('B2 · 4 thùng'), findsOneWidget);
    expect(find.text('Giá cuối / thùng'), findsNWidgets(2));
    expect(find.textContaining('chưa có giá chi tiết'), findsNothing);

    final legacy = OrderLine.fromJson({
      'sku': 'SKU001',
      'quantity': 3,
      'unitPrice': 100000,
      'allocations': [
        {'batchCode': 'B9', 'quantity': 3},
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BatchPriceBreakdown(batches: legacy.batches)),
    ));
    expect(find.textContaining('chưa có giá chi tiết'), findsOneWidget);
  });
}
