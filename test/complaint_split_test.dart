import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaint_split.dart';

ComplaintTarget part(String id,
        {required int expected, required int received, int? claimable}) =>
    ComplaintTarget(
        shipmentId: 'shipment',
        shipmentCode: 'PH-1',
        allocationId: id,
        sku: 'SKU-A',
        productName: 'A',
        batchCode: 'BATCH-$id',
        labelCode: '',
        expectedQuantity: expected,
        receivedQuantity: received,
        remainingClaimableQuantity: claimable ?? expected,
        remainingReturnableQuantity: received);

void main() {
  // Owner's example: batch A 3 sent / 3 scanned, batch B 4 sent / 3 scanned.
  final a = part('a', expected: 3, received: 3);
  final b = part('b', expected: 4, received: 3);

  test('shortage goes to the batch recorded short at receipt', () {
    final split =
        splitComplaint([a, b], 1, shortage: true, returnsGoods: false)!;
    expect(split.map((p) => (p.target.allocationId, p.quantity)), [('b', 1)]);
    expect(
        splitComplaint([a, b], 2, shortage: true, returnsGoods: false), isNull);
  });

  test('damaged fills the batch with most remaining claim first, then splits',
      () {
    final one =
        splitComplaint([a, b], 4, shortage: false, returnsGoods: false)!;
    expect(one.map((p) => (p.target.allocationId, p.quantity)), [('b', 4)]);
    final two =
        splitComplaint([a, b], 6, shortage: false, returnsGoods: false)!;
    expect(two.map((p) => (p.target.allocationId, p.quantity)),
        [('b', 4), ('a', 2)]);
    expect(splitComplaint([a, b], 8, shortage: false, returnsGoods: false),
        isNull);
  });

  test('returned goods are capped by received cartons and prior claims', () {
    final claimed = part('c', expected: 4, received: 3, claimable: 1);
    expect(complaintCapacity(b, shortage: false, returnsGoods: true), 3);
    expect(complaintCapacity(claimed, shortage: false, returnsGoods: true), 1);
    expect(splitComplaint([b], 0, shortage: false, returnsGoods: true), isNull);
  });
}
