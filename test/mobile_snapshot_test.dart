import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

void main() {
  test('maps IDs and exposes only Published products', () {
    final snapshot = SyncSnapshot.fromJson(
      mobileSnapshotFixture(),
    );

    expect(
      snapshot.products.map((product) => product.sku).toList(),
      ['SKU001', 'SKU002'],
    );

    expect(snapshot.products.first.category, 'Sữa');
    expect(snapshot.prices.single.sku, 'SKU001');
    expect(snapshot.stock.single.sku, 'SKU001');

    expect(
      snapshot.priceForProduct('product-1', snapshot.generatedAt),
      125000.5,
    );

    expect(snapshot.stockForProduct('product-1'), 42.5);
  });

  test('missing price and stock remain missing in display getters', () {
    final snapshot = SyncSnapshot.fromJson(
      mobileSnapshotFixture(),
    );

    expect(
      snapshot.priceForProduct('product-2', snapshot.generatedAt),
      isNull,
    );

    expect(snapshot.stockForProduct('product-2'), isNull);
  });

  test('category promotion retains product and retailer scope', () {
    final snapshot = SyncSnapshot.fromJson(
      mobileSnapshotFixture(),
    );

    final promotion = snapshot.promotions.single;

    expect(promotion.groupSkus, containsAll(['SKU001', 'SKU002']));
    expect(promotion.groupSkus, isNot(contains('DRAFT')));
    expect(promotion.appliesTo('10000001'), isTrue);
    expect(promotion.appliesTo('10000002'), isFalse);
    expect(snapshot.promotionCode(promotion.id), 'KM001');
  });

  test('JSON cache round-trip preserves metadata and decimals', () {
    final first = SyncSnapshot.fromJson(
      mobileSnapshotFixture(),
    );

    // Giống quá trình lưu JSON rồi đọc lại từ cache.
    final stored = jsonEncode(first.toJson());
    final restored = SyncSnapshot.fromJson(
      jsonDecode(stored) as Map<String, dynamic>,
    );

    expect(restored.version, first.version);
    expect(restored.checksum, first.checksum);
    expect(restored.generatedAt, first.generatedAt);

    expect(
      restored.priceForProduct('product-1', restored.generatedAt),
      125000.5,
    );

    expect(restored.stockForProduct('product-1'), 42.5);
    expect(restored.raw['mlors'], isEmpty);

    final catalog = CatalogData.fromSnapshot(restored);

    expect(catalog.hasSnapshot, isTrue);
    expect(catalog.lastSyncAt, first.generatedAt);
    expect(catalog.stockDisclaimer, 'Tồn chỉ để tham khảo.');
    expect(catalog.priceDisclaimer, 'Giá chốt sau allocation.');
  });

  test('exposes inherited retailer MLOR in priority guidance order', () {
    final snapshot = SyncSnapshot.fromJson(_fixtureWithMlor());
    final summaries = snapshot.mlorSummariesForRetailer('retailer-1');

    expect(summaries, hasLength(2));
    expect(summaries.first.source, 'Ngành hàng Sữa');
    expect(summaries.first.minimumLifeRatio, 0.4);
    expect(summaries.first.version, 3);
    expect(summaries.last.source, 'Mặc định hệ thống');
    expect(summaries.last.minimumLifeRatio, 0.25);
  });

  test('persists category and MLOR rows in normalized SQLite cache', () async {
    final databaseName =
        'f29_snapshot_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = AppDatabase(databaseName: databaseName);
    final repository = CatalogRepository(
      database: database,
      ownerId: 'sales-1',
      isCurrentUser: () => true,
    );

    try {
      await repository.applySnapshot(
        SyncSnapshot.fromJson(_fixtureWithMlor()),
      );
      final db = await database.database;

      expect(await db.query(Tables.category), hasLength(1));
      expect(await db.query(Tables.mlor), hasLength(1));
      final defaults = await db.query(Tables.defaultMlor);
      expect(defaults, hasLength(1));
      expect(defaults.single['minimum_life_ratio'], 0.25);
    } finally {
      final db = await database.database;
      final path = db.path;
      await database.close();
      await deleteDatabase(path);
    }
  });

  test('malformed payload is rejected instead of empty success', () {
    for (final key in ['version', 'generatedAt', 'prices']) {
      final invalid = mobileSnapshotFixture()..remove(key);

      expect(
        () => SyncSnapshot.fromJson(invalid),
        throwsFormatException,
        reason: 'Missing $key must be rejected',
      );
    }

    final invalidMode = mobileSnapshotFixture()..['deltaMode'] = 'Delta';

    expect(
      () => SyncSnapshot.fromJson(invalidMode),
      throwsFormatException,
    );
  });

  test('promotion uses exact start and end instants', () {
    final snapshot = SyncSnapshot.fromJson(
      mobileSnapshotFixture(),
    );

    final promotion = snapshot.promotions.single;

    expect(promotion.usesExactTimes, isTrue);

    expect(
      promotion.isRunning(
        DateTime.parse('2026-10-31T23:59:59Z'),
      ),
      isFalse,
    );

    expect(promotion.isRunning(snapshot.generatedAt), isTrue);

    expect(
      promotion.isRunning(
        DateTime.parse('2026-12-01T00:00:01Z'),
      ),
      isFalse,
    );
  });
}

Map<String, dynamic> _fixtureWithMlor() {
  final fixture = mobileSnapshotFixture();
  fixture['mlors'] = [
    {
      'id': 'mlor-1',
      'retailerId': 'retailer-1',
      'categoryId': 'category-1',
      'productId': null,
      'minimumLifeRatio': 0.4,
      'minimumLifeHours': null,
      'version': 3,
      'effectiveFrom': '2026-11-01T00:00:00Z',
      'effectiveTo': null,
      'isActive': true,
    },
  ];
  fixture['defaultMlor'] = {
    'minimumLifeRatio': 0.25,
    'version': 2,
    'effectiveFrom': '2026-11-01T00:00:00Z',
    'updatedAt': '2026-11-01T00:00:00Z',
  };
  return fixture;
}
