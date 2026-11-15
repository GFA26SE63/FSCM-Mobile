import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/pricing/offline_condition_builder.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

void main() {
  final at = DateTime.parse('2026-11-07T03:00:00Z');
  const lines = [
    CartLine(productId: 'product-1', sku: 'SKU001', qty: 10),
  ];

  Map<String, dynamic> fixture() {
    final json = mobileSnapshotFixture();
    json['defaultMlor'] = {
      'minimumLifeRatio': 0.5,
      'version': 2,
      'effectiveFrom': '2026-01-01T00:00:00Z',
    };
    return json;
  }

  Map<String, dynamic> rule({
    String? productId,
    String? categoryId,
    required int version,
    required double ratio,
  }) =>
      {
        'retailerId': 'retailer-1',
        'productId': productId,
        'categoryId': categoryId,
        'version': version,
        'minimumLifeRatio': ratio,
        'isActive': true,
        'effectiveFrom': '2026-01-01T00:00:00Z',
        'effectiveTo': null,
      };

  test('captures effective base price and default MLOR', () {
    final result = OfflineConditionBuilder.capture(
      snapshot: SyncSnapshot.fromJson(fixture()),
      retailerId: 'retailer-1',
      lines: lines,
      at: at,
    );

    expect(result.single.expectedBaseUnitPrice, 125000.5);
    expect(result.single.expectedMlorVersion, 2);
    expect(result.single.expectedMlorRatio, 0.5);
  });

  test('SKU override takes priority over category', () {
    final json = fixture();
    json['mlors'] = [
      rule(categoryId: 'category-1', version: 8, ratio: 0.6),
      rule(productId: 'product-1', version: 3, ratio: 0.7),
      rule(productId: 'product-1', version: 4, ratio: 0.8),
    ];

    final result = OfflineConditionBuilder.capture(
      snapshot: SyncSnapshot.fromJson(json),
      retailerId: 'retailer-1',
      lines: lines,
      at: at,
    );

    expect(result.single.expectedMlorVersion, 4);
    expect(result.single.expectedMlorRatio, 0.8);
  });

  test('resolves ancestor category when direct category has no rule', () {
    final json = fixture();
    final categories = List<Map<String, dynamic>>.from(
      json['categories'] as List<dynamic>,
    );
    json['categories'] = categories;
    categories.first['parentCategoryId'] = 'parent-category';

    categories.add({
      'id': 'parent-category',
      'parentCategoryId': null,
      'name': 'Danh mục cha',
      'isActive': true,
    });

    json['mlors'] = [
      rule(categoryId: 'parent-category', version: 5, ratio: 0.65),
    ];

    final result = OfflineConditionBuilder.capture(
      snapshot: SyncSnapshot.fromJson(json),
      retailerId: 'retailer-1',
      lines: lines,
      at: at,
    );

    expect(result.single.expectedMlorVersion, 5);
    expect(result.single.expectedMlorRatio, 0.65);
  });

  test('does not invent MLOR when snapshot lacks all applicable rules', () {
    final json = fixture();
    json['defaultMlor'] = null;

    expect(
      () => OfflineConditionBuilder.capture(
        snapshot: SyncSnapshot.fromJson(json),
        retailerId: 'retailer-1',
        lines: lines,
        at: at,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
