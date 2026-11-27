import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/local/receipt_draft_store.dart';
import 'package:fscm_mobile/data/models/delivery_shipment.dart';
import 'package:shared_preferences/shared_preferences.dart';

DeliveryShipment _shipment({String status = 'Delivering', int version = 5}) =>
    DeliveryShipment.fromJson(<String, dynamic>{
      'id': 's1',
      'shipmentCode': 'GH-1',
      'warehouseCode': 'WH-A',
      'status': status,
      'version': version,
      'totalQuantity': 5.0,
      'receivedQuantity': 0,
      'lines': <dynamic>[],
    });

void main() {
  var now = DateTime(2026, 11, 27, 9);
  ReceiptDraftStore store(String owner) =>
      ReceiptDraftStore(ownerId: owner, now: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    now = DateTime(2026, 11, 27, 9);
  });

  test('saved codes come back for the same shipment and user only', () async {
    await store('u1').save(_shipment(), ['CID-1', 'CID-2']);

    expect(await store('u1').read(_shipment()), ['CID-1', 'CID-2']);
    expect(await store('u2').read(_shipment()), isEmpty);
  });

  test('a draft is dropped when the shipment moved on or it is too old',
      () async {
    await store('u1').save(_shipment(), ['CID-1']);
    expect(await store('u1').read(_shipment(version: 6)), isEmpty);
    // Dropped for good, not only hidden.
    expect(await store('u1').read(_shipment()), isEmpty);

    await store('u1').save(_shipment(), ['CID-1']);
    expect(await store('u1').read(_shipment(status: 'Received')), isEmpty);

    await store('u1').save(_shipment(), ['CID-1']);
    now = now.add(ReceiptDraftStore.maxAge + const Duration(minutes: 1));
    expect(await store('u1').read(_shipment()), isEmpty);
  });

  test('saving an empty list or clearing removes the draft', () async {
    await store('u1').save(_shipment(), ['CID-1']);
    await store('u1').save(_shipment(), const <String>[]);
    expect(await store('u1').read(_shipment()), isEmpty);

    await store('u1').save(_shipment(), ['CID-1']);
    await store('u1').clear('s1');
    expect(await store('u1').read(_shipment()), isEmpty);
  });
}
