import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';

Map<String, dynamic> fixture() {
  final now = DateTime.now().toUtc();

  final start = now.subtract(const Duration(days: 1)).toIso8601String();
  final end = now.add(const Duration(days: 1)).toIso8601String();

  return {
    'version': 'f29-v1-test',
    'checksum': 'test-checksum',
    'deltaMode': 'Full',
    'generatedAt': now.toIso8601String(),
    'retailers': [
      {
        'id': 'retailer-1',
        'code': '10000001',
        'name': 'Điểm bán A',
        'address': 'Địa chỉ A',
        'status': 'Active',
        'creditTermDays': 14,
      },
      {
        'id': 'retailer-2',
        'code': '10000002',
        'name': 'Điểm bán B',
        'status': 'Active',
        'creditTermDays': 0,
      },
    ],
    'categories': [
      {
        'id': 'category-1',
        'name': 'Sữa',
        'isActive': true,
      },
    ],
    'products': [
      {
        'id': 'product-1',
        'categoryId': 'category-1',
        'sku': 'SKU001',
        'name': 'Sản phẩm 1',
        'unit': 'Thùng',
        'shelfLifeHours': 720,
        'status': 'Published',
      },
      {
        'id': 'product-2',
        'categoryId': 'category-1',
        'sku': 'SKU002',
        'name': 'Sản phẩm 2',
        'unit': 'Thùng',
        'shelfLifeHours': 720,
        'status': 'Published',
      },
      {
        'id': 'product-draft',
        'categoryId': 'category-1',
        'sku': 'DRAFT',
        'name': 'Chưa bán',
        'unit': 'Thùng',
        'shelfLifeHours': 720,
        'status': 'Draft',
      },
    ],
    'prices': [
      {
        'id': 'price-1',
        'productId': 'product-1',
        'unitPrice': 125000.5,
        'effectiveFrom': start,
        'effectiveTo': end,
        'isActive': true,
      },
    ],
    'promotions': [
      {
        'id': 'promotion-1',
        'code': 'KM001',
        'name': 'Khuyến mãi nhóm',
        'type': 'Campaign',
        'minimumQuantity': 10,
        'discountPercent': 5,
        'startAt': start,
        'endAt': end,
        'isActive': true,
        'productIds': [],
        'categoryIds': ['category-1'],
        'retailerIds': ['retailer-1'],
      },
    ],
    'indicativeStock': [
      {
        'productId': 'product-1',
        'indicativeAvailableQuantity': 42.5,
      },
    ],
    'mlors': [],
    'defaultMlor': null,
    'stockDisclaimer': 'Tồn chỉ để tham khảo.',
    'priceDisclaimer': 'Giá chốt sau allocation.',
  };
}

void main() {
  test('Maps product/category/price/stock by backend IDs', () {
    final snapshot = SyncSnapshot.fromJson(fixture());

    expect(snapshot.products.length, 2);
    expect(snapshot.products.first.category, 'Sữa');

    expect(snapshot.prices.single.sku, 'SKU001');
    expect(snapshot.stock.single.sku, 'SKU001');

    expect(
      snapshot.priceForProduct('product-1', DateTime.now().toUtc()),
      125000.5,
    );

    expect(snapshot.stockForProduct('product-1'), 42.5);
  });

  test('Category promotion includes matching SKUs and retailer scope', () {
    final snapshot = SyncSnapshot.fromJson(fixture());
    final promotion = snapshot.promotions.single;

    expect(
      promotion.groupSkus,
      containsAll(['SKU001', 'SKU002']),
    );

    expect(promotion.appliesTo('10000001'), isTrue);
    expect(promotion.appliesTo('10000002'), isFalse);

    expect(snapshot.promotionCode(promotion.id), 'KM001');
  });

  test('Missing price is displayed as missing instead of zero', () {
    final snapshot = SyncSnapshot.fromJson(fixture());

    expect(
      snapshot.priceForProduct('product-2', DateTime.now().toUtc()),
      isNull,
    );
  });

  test('Raw snapshot round-trip preserves backend precision', () {
    final first = SyncSnapshot.fromJson(fixture());
    final restored = SyncSnapshot.fromJson(first.toJson());

    expect(
      restored.priceForProduct('product-1', DateTime.now().toUtc()),
      125000.5,
    );

    expect(restored.stockForProduct('product-1'), 42.5);
    expect(restored.version, first.version);
  });

  test('Invalid payload does not silently become an empty snapshot', () {
    final invalid = fixture()..remove('prices');

    expect(
      () => SyncSnapshot.fromJson(invalid),
      throwsFormatException,
    );
  });

  test('Expired promotion is excluded from catalog browsing', () {
    final json = fixture();
    final rows = json['promotions'] as List;

    (rows.single as Map<String, dynamic>)['endAt'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 1))
        .toIso8601String();

    final data = CatalogData.fromSnapshot(
      SyncSnapshot.fromJson(json),
    );

    expect(data.runningPromotions(), isEmpty);
  });
}
