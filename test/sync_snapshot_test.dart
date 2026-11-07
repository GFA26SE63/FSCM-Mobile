import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/pricing/promotion_calculator.dart';

void main() {
  test(
      'per-SKU snapshot preserves independent thresholds across sync and cache',
      () {
    final snapshot = SyncSnapshot.fromJson({
      'generatedAt': '2026-11-07T03:00:00Z',
      'retailers': [
        {'id': 'r1', 'code': 'DEMO'}
      ],
      'products': [
        {'id': 'p1', 'sku': 'SKU001'},
        {'id': 'p2', 'sku': 'SKU002'}
      ],
      'prices': [
        {'productId': 'p1', 'unitPrice': 100000, 'effectiveFrom': '2026-01-01'},
        {'productId': 'p2', 'unitPrice': 100000, 'effectiveFrom': '2026-01-01'}
      ],
      'promotions': [
        {
          'id': 'km1',
          'name': 'Điều kiện từng SKU',
          'minimumQuantity': 10,
          'discountPercent': 7,
          'campaignMode': 'PerSku',
          'isActive': true,
          'startAt': '2026-01-01',
          'endAt': '2027-01-01',
          'productIds': ['p1', 'p2'],
          'categoryIds': [],
          'retailerIds': ['r1'],
          'productRules': [
            {'productId': 'p1', 'minimumQuantity': 10, 'discountPercent': 5},
            {'productId': 'p2', 'minimumQuantity': 30, 'discountPercent': 7}
          ],
        }
      ],
    });
    final cached = SyncSnapshot.fromJson(snapshot.toJson());
    expect(cached.promotions.single.type, 1);
    final quote = PromotionCalculator.quote(
      lines: [
        const CartLine(sku: 'SKU001', qty: 9),
        const CartLine(sku: 'SKU002', qty: 30)
      ],
      retailerCode: 'DEMO',
      promotions: cached.promotions,
      products: {for (final p in cached.products) p.sku: p},
      prices: {for (final p in cached.prices) p.sku: p.price},
      now: snapshot.serverTime,
    );
    expect(quote.discount, 210000);
    expect(cached.promotions.single.rules.first.minQty, 10);
  });

  test('joins server prices, stock and promotion scopes to SKU codes', () {
    final snapshot = SyncSnapshot.fromJson({
      'generatedAt': '2026-11-06T03:00:00Z',
      'retailers': [
        {'id': 'r1', 'code': 'DEMO'},
      ],
      'categories': [
        {'id': 'c1', 'name': 'Sữa'},
      ],
      'products': [
        {'id': 'p1', 'sku': 'SKU001', 'name': 'Sữa', 'categoryId': 'c1'},
      ],
      'prices': [
        {'productId': 'p1', 'unitPrice': 252000, 'effectiveFrom': '2026-10-01'},
      ],
      'indicativeStock': [
        {'productId': 'p1', 'indicativeAvailableQuantity': 150},
      ],
      'promotions': [
        {
          'id': 'promo1',
          'name': 'Giảm 8%',
          'type': 'Campaign',
          'minimumQuantity': 10,
          'discountPercent': 8,
          'startAt': '2026-11-06T02:00:00Z',
          'endAt': '2026-11-06T04:00:00Z',
          'isActive': true,
          'productIds': [],
          'categoryIds': ['c1'],
          'retailerIds': ['r1'],
        },
      ],
    });
    expect(snapshot.prices.single.sku, 'SKU001');
    expect(snapshot.prices.single.price, 252000);
    expect(snapshot.stock.single.sku, 'SKU001');
    expect(snapshot.stock.single.available, 150);
    expect(snapshot.products.single.basePrice, 252000);
    expect(snapshot.products.single.category, 'Sữa');
    final quote = PromotionCalculator.quote(
      lines: [const CartLine(sku: 'SKU001', qty: 10)],
      retailerCode: 'DEMO',
      promotions: snapshot.promotions,
      products: {for (final p in snapshot.products) p.sku: p},
      prices: {for (final p in snapshot.prices) p.sku: p.price},
      now: snapshot.serverTime,
    );
    expect(quote.total, 2520000);
    expect(quote.discount, 201600);
    expect(snapshot.promotions.single.appliesTo('OTHER'), isFalse);
    expect(
        snapshot.promotions.single
            .isRunning(DateTime.parse('2026-11-06T01:59:00Z')),
        isFalse);
    final cached = SyncSnapshot.fromJson(snapshot.toJson());
    expect(cached.prices.single.price, 252000);
    expect(cached.stock.single.available, 150);
    expect(cached.promotions.single.usesExactTimes, isTrue);
  });

  test('continues reading cached snapshots keyed by SKU', () {
    final snapshot = SyncSnapshot.fromJson({
      'serverTime': '2026-11-06T03:00:00Z',
      'products': [
        {'sku': 'SKU001', 'basePrice': 100}
      ],
      'prices': [
        {'sku': 'SKU001', 'price': 100}
      ],
      'stock': [
        {'sku': 'SKU001', 'available': 50}
      ],
    });
    expect(snapshot.prices.single.price, 100);
    expect(snapshot.stock.single.available, 50);
  });
}
