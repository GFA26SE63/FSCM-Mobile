class LoyaltyTransaction {
  const LoyaltyTransaction({
    required this.date,
    required this.description,
    required this.points,
    this.isPending = false,
  });

  final String date;
  final String description;
  final int points;
  final bool isPending;
}

class RetailerComplaint {
  const RetailerComplaint({
    required this.orderId,
    required this.batchCode,
    required this.expectedQuantity,
    required this.actualQuantity,
    required this.note,
    required this.evidenceCount,
  });

  final String orderId;
  final String batchCode;
  final int expectedQuantity;
  final int actualQuantity;
  final String note;
  final int evidenceCount;
}

enum LabelScanResult { matched, alreadyScanned, wrongRetailer, unknown }
