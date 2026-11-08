import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/pricing/promotion_calculator.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

void main() {
  test('group promotion works after snapshot cache round-trip', () {
    final json = mobileSnapshotFixture();

    final prices = json['prices'] as List;
    (prices.first as Map<String, dynamic>)['unitPrice'] = 100000;

    final original = SyncSnapshot.fromJson(json);
    final snapshot = SyncSnapshot.fromJson(original.toJson());

    final quote = PromotionCalculator.quote(
      lines: [
        const CartLine(sku: 'SKU001', qty: 10),
      ],
      retailerCode: '10000001',
      promotions: snapshot.promotions,
      products: {
        for (final product in snapshot.products) product.sku: product,
      },
      prices: {
        for (final price in snapshot.prices) price.sku: price.price,
      },
      now: snapshot.serverTime,
    );

    expect(quote.total, 1000000);
    expect(quote.discount, 50000);
  });

  test('PerSku rules remain independent when payload provides them', () {
    final json = mobileSnapshotFixture();

    json['prices'] = [
      {
        'productId': 'product-1',
        'unitPrice': 100000,
        'effectiveFrom': '2026-01-01T00:00:00Z',
        'isActive': true,
      },
      {
        'productId': 'product-2',
        'unitPrice': 100000,
        'effectiveFrom': '2026-01-01T00:00:00Z',
        'isActive': true,
      },
    ];

    final promotion =
        (json['promotions'] as List).first as Map<String, dynamic>;

    promotion['campaignMode'] = 'PerSku';
    promotion['productRules'] = [
      {
        'productId': 'product-1',
        'minimumQuantity': 10,
        'discountPercent': 5,
      },
      {
        'productId': 'product-2',
        'minimumQuantity': 30,
        'discountPercent': 7,
      },
    ];

    final original = SyncSnapshot.fromJson(json);
    final snapshot = SyncSnapshot.fromJson(original.toJson());

    expect(snapshot.promotions.single.type, 1);
    expect(snapshot.promotions.single.rules.length, 2);

    final quote = PromotionCalculator.quote(
      lines: [
        const CartLine(sku: 'SKU001', qty: 9),
        const CartLine(sku: 'SKU002', qty: 30),
      ],
      retailerCode: '10000001',
      promotions: snapshot.promotions,
      products: {
        for (final product in snapshot.products) product.sku: product,
      },
      prices: {
        for (final price in snapshot.prices) price.sku: price.price,
      },
      now: snapshot.serverTime,
    );

    // SKU001 chưa đạt 10; chỉ SKU002 đạt 30 và nhận 7%.
    expect(quote.discount, 210000);
  });

  test('empty product/category scope includes Published products', () {
    final json = mobileSnapshotFixture();
    final promotion =
        (json['promotions'] as List).first as Map<String, dynamic>;

    promotion['productIds'] = <String>[];
    promotion['categoryIds'] = <String>[];

    final snapshot = SyncSnapshot.fromJson(json);

    expect(
      snapshot.promotions.single.groupSkus,
      containsAll(['SKU001', 'SKU002']),
    );

    expect(
      snapshot.promotions.single.groupSkus,
      isNot(contains('DRAFT')),
    );
  });

  test('price is valid at start and invalid at exclusive end', () {
    final snapshot = SyncSnapshot.fromJson(
      mobileSnapshotFixture(),
    );

    expect(
      snapshot.priceForProduct(
        'product-1',
        DateTime.parse('2026-11-01T00:00:00Z'),
      ),
      125000.5,
    );

    expect(
      snapshot.priceForProduct(
        'product-1',
        DateTime.parse('2026-12-01T00:00:00Z'),
      ),
      isNull,
    );
  });

  test('invalid snapshot does not substitute current time', () {
    final json = mobileSnapshotFixture()..['generatedAt'] = 'not-a-date';

    expect(
      () => SyncSnapshot.fromJson(json),
      throwsFormatException,
    );
  });
}
