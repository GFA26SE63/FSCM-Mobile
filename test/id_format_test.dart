import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/utils/id_format.dart';

void main() {
  group('IdFormat builders', () {
    test('zero-padded business ids', () {
      expect(IdFormat.retailer(10004127), '10004127');
      expect(IdFormat.retailer(42), '00000042');
      expect(IdFormat.sku(2), 'SKU002');
      expect(IdFormat.label(187), 'TEM-000187');
      expect(IdFormat.order(1030), 'DH-001030');
      expect(IdFormat.promotion(3), 'KM-003');
      expect(IdFormat.gift(5), 'QUA-005');
      expect(IdFormat.registration(9), 'KB-0009');
      expect(IdFormat.salesGroup('q12', 'a'), 'Q12-A');
    });

    test('batch, picking list and documents', () {
      expect(
        IdFormat.batch('WH-GV', 'SKU002', DateTime(2026, 10, 12)),
        'WH-GV-SKU002-12102026',
      );
      expect(IdFormat.pickingList('DH-001024', 1), 'DH-001024B');
      expect(IdFormat.document(DocPrefix.dc, DateTime(2026, 9, 27), 1),
          'DC-260927-01');
      expect(IdFormat.document(DocPrefix.kn, DateTime(2026, 10, 5), 12),
          'KN-261005-12');
      expect(IdFormat.giftRequest(DateTime(2026, 9, 10), 1), 'DQ-260910-01');
    });

    test('offline order code is paired with the device code', () {
      expect(IdFormat.offlineOrder('m3f7', 12), 'OFF-M3F7-0012');
      expect(IdFormat.offlineSeq('OFF-M3F7-0012'), 12);
      expect(IdFormat.offlineSeq('DH-001030'), isNull);
    });

    test('rejects values wider than the field', () {
      expect(() => IdFormat.label(1000000), throwsArgumentError);
      expect(() => IdFormat.sku(-1), throwsArgumentError);
      expect(() => IdFormat.pickingList('DH-001024', 26), throwsArgumentError);
    });
  });

  group('IdFormat validators', () {
    test('accepts well-formed codes', () {
      expect(IdFormat.isLabel('TEM-000187'), isTrue);
      expect(IdFormat.isOrder('DH-001030'), isTrue);
      expect(IdFormat.isPickingList('DH-001021A'), isTrue);
      expect(IdFormat.isDocument('DC-260926-01'), isTrue);
      expect(IdFormat.isOfflineOrder('OFF-M3F7-0001'), isTrue);
      expect(IdFormat.isBatch('WH-TA-SKU001-18102026'), isTrue);
      expect(IdFormat.isRetailer('10004127'), isTrue);
    });

    test('rejects malformed codes', () {
      expect(IdFormat.isLabel('TEM-1234'), isFalse);
      expect(IdFormat.isLabel('tem-000187'), isFalse);
      expect(IdFormat.isOrder('DH-1030'), isFalse);
      expect(IdFormat.isPickingList('DH-001021'), isFalse);
      expect(IdFormat.isRetailer('1000412'), isFalse);
      expect(IdFormat.isBatch('WH-TA-SKU001-18102026X'), isFalse);
    });

    test('batchExpiry reads the date out of the batch code', () {
      expect(IdFormat.batchExpiry('WH-GV-SKU002-12102026'),
          DateTime(2026, 10, 12));
      expect(IdFormat.batchExpiry('WH-GV-SKU002-31022026'), isNull);
      expect(IdFormat.batchExpiry('not-a-batch'), isNull);
    });

    test('orderOfPickingList strips the warehouse letter', () {
      expect(IdFormat.orderOfPickingList('DH-001024B'), 'DH-001024');
      expect(IdFormat.orderOfPickingList('DH-001024'), isNull);
    });
  });

  group('IdFormat.classify', () {
    test('recognises what a QR can carry', () {
      expect(IdFormat.classify('TEM-000187'), ScannedCodeKind.label);
      expect(IdFormat.classify(' tem-000187 '), ScannedCodeKind.label);
      expect(IdFormat.classify('DH-001024B'), ScannedCodeKind.pickingList);
      expect(IdFormat.classify('DH-001024'), ScannedCodeKind.order);
      expect(IdFormat.classify('DC-260926-01'), ScannedCodeKind.document);
      expect(IdFormat.classify('10004127'), ScannedCodeKind.retailer);
      expect(IdFormat.classify('hello'), ScannedCodeKind.unknown);
    });
  });
}
