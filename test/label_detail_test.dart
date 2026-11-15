import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/label_detail.dart';

Map<String, dynamic> label(
  String code, {
  String? parent,
  String status = 'Available',
}) {
  return {
    'qrCode': code,
    'sku': 'SKU001',
    'productName': 'Sữa tươi',
    'batchCode': 'BATCH-01',
    'warehouseCode': 'WH-TP',
    'quantity': 10,
    'status': status,
    'version': 3,
    'expirationDate': '2026-12-01',
    'parentQrCode': parent,
    'rootQrCode': 'TEM-000001',
  };
}

void main() {
  test('parse wrapper, direct children and root-chain events', () {
    final detail = LabelDetail.fromJson({
      'label': label('TEM-000002', parent: 'TEM-000001'),
      'lineage': [
        label('TEM-000001'),
        label('TEM-000002', parent: 'TEM-000001'),
        label('TEM-000003', parent: 'TEM-000002'),
        label('TEM-000004', parent: 'TEM-000001'),
      ],
      'events': [
        {
          'id': 'later',
          'eventType': 'Split',
          'quantity': 10,
          'occurredAt': '2026-11-06T02:00:00Z',
        },
        {
          'id': 'earlier',
          'eventType': 'Generated',
          'quantity': 20,
          'occurredAt': '2026-11-06T01:00:00Z',
        },
      ],
    });

    expect(detail.label.code, 'TEM-000002');
    expect(detail.label.version, 3);
    expect(detail.rootCode, 'TEM-000001');

    expect(
      detail.children.map((item) => item.code).toList(),
      ['TEM-000003'],
    );

    expect(detail.events.first.id, 'earlier');
    expect(detail.events.last.type, 'Split');
  });

  test('invalidated and unknown never become in-stock', () {
    expect(
      LabelStatus.fromCode('Invalidated'),
      LabelStatus.invalidated,
    );

    expect(
      LabelStatus.fromCode('SomeFutureStatus'),
      LabelStatus.unknown,
    );
  });

  test('reject malformed detail instead of displaying empty label', () {
    expect(
      () => LabelDetail.fromJson({
        'label': {},
        'lineage': [],
        'events': [],
      }),
      throwsFormatException,
    );
  });
}
