import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_order_eligibility.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';

import 'fixtures/mobile_snapshot_fixture.dart';

void main() {
  test('snapshot cache preserves retailer status and credit term', () {
    final snapshot = SyncSnapshot.fromJson(mobileSnapshotFixture());

    final cached = SyncSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
    );

    final retailer = cached.retailers.firstWhere(
      (item) => item.code == '10000001',
    );

    expect(retailer.id, 'retailer-1');
    expect(retailer.status, 'Active');
    expect(retailer.creditTerm, 14);

    final restored = Retailer.fromJson(
      jsonDecode(jsonEncode(retailer.toJson())) as Map<String, dynamic>,
    );

    expect(restored.status, 'Active');
    expect(restored.creditTerm, 14);
  });

  test('missing retailer status does not default to Active', () {
    final retailer = Retailer.fromJson({
      'id': 'retailer-1',
      'code': '10000001',
      'name': 'Điểm bán A',
    });

    expect(retailer.status, '');
    expect(retailer.statusLabel, 'Chưa có trạng thái');
  });

  test('eligibility preserves backend denial reasons', () {
    final result = RetailerOrderEligibility.fromJson({
      'salesUserId': 'sales-1',
      'retailerId': 'retailer-1',
      'isEligible': false,
      'salesGroupId': null,
      'salesGroupCode': null,
      'retailerStatus': 'Active',
      'creditTermDays': 14,
      'reasons': [
        "Retailer is outside the Sales user's assigned territory.",
      ],
    });

    expect(result.isEligible, isFalse);
    expect(result.denialMessage, contains('assigned territory'));
  });

  test('malformed eligibility cannot silently allow an order', () {
    expect(
      () => RetailerOrderEligibility.fromJson({
        'salesUserId': 'sales-1',
        'retailerId': 'retailer-1',
        'isEligible': 'true',
        'reasons': <String>[],
      }),
      throwsFormatException,
    );
  });

  test('eligible response carries current credit term', () {
    final result = RetailerOrderEligibility.fromJson({
      'salesUserId': 'sales-1',
      'retailerId': 'retailer-1',
      'isEligible': true,
      'salesGroupId': 'group-1',
      'salesGroupCode': 'SG01',
      'retailerStatus': 'Active',
      'creditTermDays': 30,
      'reasons': <String>[],
    });

    expect(result.isEligible, isTrue);
    expect(result.creditTermDays, 30);
  });
}
