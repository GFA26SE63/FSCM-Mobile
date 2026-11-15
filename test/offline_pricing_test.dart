import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/models/offline_expected_condition.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

void main() {
  final at = DateTime.parse('2026-11-07T03:00:00Z');

  CatalogData catalog(Map<String, dynamic> json) =>
      CatalogData.fromSnapshot(SyncSnapshot.fromJson(json));

  test('keeps decimal unit price until line amount is calculated', () {
    final data = catalog(mobileSnapshotFixture());

    final quote = data.quote(
      [const CartLine(sku: 'SKU001', qty: 10)],
      '10000001',
      now: at,
    );

    expect(quote.isComplete, isTrue);
    expect(quote.lines.single.unitPrice, 125000.5);
    expect(quote.total, 1250005);
    expect(quote.discount, 62500);
  });

  test('missing price is reported instead of using product fallback', () {
    final json = mobileSnapshotFixture();
    json['prices'] = <Map<String, dynamic>>[];

    final quote = catalog(json).quote(
      [const CartLine(sku: 'SKU001', qty: 10)],
      '10000001',
      now: at,
    );

    expect(quote.isComplete, isFalse);
    expect(quote.missingPriceSkus, ['SKU001']);
    expect(quote.lines, isEmpty);
  });

  test('promotion is recalculated when quantity changes', () {
    final data = catalog(mobileSnapshotFixture());

    final below = data.quote(
      [const CartLine(sku: 'SKU001', qty: 9)],
      '10000001',
      now: at,
    );
    final reached = data.quote(
      [const CartLine(sku: 'SKU001', qty: 10)],
      '10000001',
      now: at,
    );

    expect(below.discount, 0);
    expect(reached.discount, greaterThan(0));
  });

  test('retailer outside promotion scope gets no discount', () {
    final quote = catalog(mobileSnapshotFixture()).quote(
      [const CartLine(sku: 'SKU001', qty: 10)],
      '10000002',
      now: at,
    );

    expect(quote.discount, 0);
  });

  test('expired price is unavailable at estimate time', () {
    final quote = catalog(mobileSnapshotFixture()).quote(
      [const CartLine(sku: 'SKU001', qty: 10)],
      '10000001',
      now: DateTime.parse('2027-01-01T00:00:00Z'),
    );

    expect(quote.isComplete, isFalse);
    expect(quote.missingPriceSkus, ['SKU001']);
  });

  test('local persistence retains quote and API request excludes local fields',
      () {
    final data = catalog(mobileSnapshotFixture());
    final quote = data.quote(
      [const CartLine(sku: 'SKU001', qty: 10)],
      '10000001',
      now: at,
    );

    final payload = OfflineOrderPayload(
      clientRequestId: 'request-1',
      offlineCode: 'OFF-TEST-0001',
      retailerId: 'retailer-1',
      retailerCode: '10000001',
      retailerName: 'Điểm bán A',
      createdAt: at,
      lines: const [
        CartLine(productId: 'product-1', sku: 'SKU001', qty: 10),
      ],
      localTotal: quote.total,
      localDiscount: quote.discount,
      localQuote: quote,
      estimatedAt: at,
      snapshotVersion: 'snapshot-test-v1',
      expectedConditions: const [
        OfflineExpectedCondition(
          productId: 'product-1',
          expectedBaseUnitPrice: 125000.5,
          expectedMlorVersion: 1,
          expectedMlorRatio: 0.5,
        ),
      ],
    );

    final restored = OfflineOrderPayload.fromJson(
      jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
    );

    expect(restored.clientRequestId, payload.clientRequestId);
    expect(restored.offlineCode, payload.offlineCode);
    expect(restored.localQuote!.lines.single.unitPrice, 125000.5);
    expect(restored.localFinal, quote.finalAmount);
    expect(restored.estimatedAt, at);

    final request = restored.toRequestJson();
    expect(restored.hasCompleteExpectedConditions, isTrue);
    expect(
      request['expectedConditions'],
      [
        {
          'productId': 'product-1',
          'expectedBaseUnitPrice': 125000.5,
          'expectedMlorVersion': 1,
          'expectedMlorRatio': 0.5,
        },
      ],
    );
    expect(request['clientOrderKey'], 'request-1');
    expect(request['offlineEstimatedAmount'], quote.finalAmount);
    expect(request.containsKey('localQuote'), isFalse);
    expect(request.containsKey('localTotal'), isFalse);

    final entry = OfflineOrder(
      clientRequestId: restored.clientRequestId,
      payload: restored,
      status: SyncStatus.pending,
      createdAt: at,
    );

    final order = orderFromOffline(entry);
    expect(order.lines.single.unitPrice, 125000.5);
    expect(order.total, quote.total);
    expect(order.finalAmount, quote.finalAmount);
  });

  test('backend offline comparison fields are mapped', () {
    final order = Order.fromJson({
      'orderCode': 'DH-TEST',
      'source': 'Offline',
      'createdAt': at.toIso8601String(),
      'subtotalAmount': 1000000,
      'discountAmount': 50000,
      'offlineEstimatedAmount': 900000,
      'hasOfflineDifference': true,
      'lines': <Map<String, dynamic>>[],
    });

    expect(order.isOffline, isTrue);
    expect(order.localFinal, 900000);
    expect(order.finalAmount, 950000);
    expect(order.promoChanged, isTrue);
  });
}
