Map<String, dynamic> loyaltyLedgerFixture({
  String type = 'Earned',
  int points = 500,
  String id = 'tx-1',
  String? orderId,
  String? redemptionId,
}) =>
    {
      'transactionId': id,
      'transactionType': type,
      'points': points,
      'balanceAfter': 500,
      'note': 'Lý do do máy chủ trả về',
      'createdAt': '2026-11-11T00:00:00Z',
      'salesOrderId': orderId,
      'orderCode': orderId == null ? null : 'DH-001',
      'redemptionId': redemptionId,
      'redemptionStatus': redemptionId == null ? null : 'Pending',
    };

Map<String, dynamic> loyaltyCardFixture({
  int balance = 500,
  String? programId = 'program-1',
  List<Map<String, dynamic>>? ledger,
}) =>
    {
      'retailerId': 'retailer-1',
      'retailerCode': '1001',
      'retailerName': 'Cửa hàng có tên dài để kiểm tra bố cục trên điện thoại',
      'availablePoints': balance,
      'pendingPoints': 100,
      'heldPoints': 50,
      'expiredPoints': 20,
      'programId': programId,
      'programCode': programId == null ? null : 'LP-001',
      'programName': programId == null ? null : 'Chương trình thử nghiệm',
      'pointsExpireAt': null,
      'ledger': ledger ?? [loyaltyLedgerFixture()],
    };

Map<String, dynamic> loyaltyProgramFixture() => {
      'id': 'program-1',
      'code': 'LP-001',
      'name': 'Chương trình thử nghiệm',
      'spendAmountPerPoint': 12345.67,
      'isActive': false,
      'startAt': '2026-11-01T00:00:00Z',
      'endAt': '2026-12-01T00:00:00Z',
      'pointsExpireAt': null,
    };
