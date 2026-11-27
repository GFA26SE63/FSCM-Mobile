import 'package:fscm_mobile/data/models/complaint.dart';

/// One request to send: [quantity] affected cartons on [target]'s batch.
typedef ComplaintPart = ({ComplaintTarget target, int quantity});

/// Cartons expected but not scanned at receipt for this batch part.
int shortfallOf(ComplaintTarget t) {
  final received = t.receivedQuantity ?? t.expectedQuantity;
  return t.expectedQuantity - received < 0 ? 0 : t.expectedQuantity - received;
}

/// How many affected cartons one request on [t] may carry.
///
/// Mirrors the per-part limits the server enforces: claim limit always,
/// return limit when goods are returned/collected, and for a Shortage
/// complaint only the cartons recorded missing at receipt.
int complaintCapacity(ComplaintTarget t,
    {required bool shortage, required bool returnsGoods}) {
  var capacity = t.remainingClaimableQuantity ?? t.expectedQuantity;
  if (returnsGoods) {
    final returnLimit = t.remainingReturnableQuantity ??
        t.receivedQuantity ??
        t.expectedQuantity;
    if (returnLimit < capacity) capacity = returnLimit;
  }
  if (shortage) {
    final missing = shortfallOf(t);
    if (missing < capacity) capacity = missing;
  }
  return capacity < 0 ? 0 : capacity;
}

/// Splits [quantity] cartons of one SKU across its batch parts.
///
/// The retailer only picks the SKU; the batch is attached here. Parts with
/// the most capacity go first, so a request touches as few batches as
/// possible. Returns null when [quantity] exceeds the SKU's total capacity.
List<ComplaintPart>? splitComplaint(List<ComplaintTarget> parts, int quantity,
    {required bool shortage, required bool returnsGoods}) {
  if (quantity <= 0) return null;
  final ranked = [
    for (final t in parts)
      (
        target: t,
        quantity:
            complaintCapacity(t, shortage: shortage, returnsGoods: returnsGoods)
      )
  ]..sort((a, b) {
      final byCapacity = b.quantity.compareTo(a.quantity);
      return byCapacity != 0
          ? byCapacity
          : a.target.allocationId.compareTo(b.target.allocationId);
    });
  final result = <ComplaintPart>[];
  var left = quantity;
  for (final part in ranked) {
    if (left == 0) break;
    if (part.quantity <= 0) continue;
    final take = part.quantity < left ? part.quantity : left;
    result.add((target: part.target, quantity: take));
    left -= take;
  }
  return left == 0 ? result : null;
}
