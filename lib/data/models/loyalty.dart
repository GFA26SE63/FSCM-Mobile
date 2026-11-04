import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Loyalty program `LP-000`: 1 point per [amountPerPoint] (đ) after promotion.
class LoyaltyProgram {
  const LoyaltyProgram({
    required this.id,
    required this.code,
    required this.name,
    required this.amountPerPoint,
    this.expiryText = '',
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> j) => LoyaltyProgram(
        id: asStr(j['id']),
        code: asStr(j['code']),
        name: asStr(j['name']),
        amountPerPoint:
            asInt(j['spendAmountPerPoint'] ?? j['amountPerPoint'], 100000),
        expiryText: asStr(j['expiryText'] ?? j['pointsExpireAt']),
      );

  final String id;
  final String code;
  final String name;
  final int amountPerPoint;
  final String expiryText;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'amountPerPoint': amountPerPoint,
        'expiryText': expiryText,
      };
}

class PointLedgerEntry {
  const PointLedgerEntry({
    required this.date,
    required this.description,
    required this.points,
    required this.kind,
    this.orderCode = '',
  });

  factory PointLedgerEntry.fromJson(Map<String, dynamic> j) => PointLedgerEntry(
        date: asDate(j['createdAt'] ?? j['date']),
        description: _ledgerDescription(j),
        points: asInt(j['points']),
        kind:
            PointKind.fromCode(asStrOrNull(j['transactionType'] ?? j['kind'])),
        orderCode: asStr(j['orderCode']),
      );

  final DateTime? date;
  final String description;

  /// Signed points (negative for redemptions / holds).
  final int points;
  final PointKind kind;
  final String orderCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': isoOrNull(date),
        'description': description,
        'points': points,
        'kind': kind.code,
        'orderCode': orderCode,
      };
}

/// Response of `GET /loyalty/retailers/{code}`.
class LoyaltyAccount {
  const LoyaltyAccount({
    required this.retailerCode,
    required this.balance,
    required this.program,
    required this.ledger,
    this.pending = 0,
    this.held = 0,
    this.tier = '',
  });

  factory LoyaltyAccount.fromJson(Map<String, dynamic> j,
          {LoyaltyProgram? program}) =>
      LoyaltyAccount(
        retailerCode: asStr(j['retailerCode']),
        balance: asInt(j['availablePoints'] ?? j['balance']),
        pending: asInt(j['pendingPoints'] ?? j['pending']),
        held: asInt(j['heldPoints'] ?? j['held']),
        tier: asStr(j['tier']),
        program: program ??
            LoyaltyProgram(
              id: asStr(j['programId']),
              code: asStr(j['programCode'], '-'),
              name: asStr(j['programName'], 'Chưa có chương trình'),
              amountPerPoint: 0,
              expiryText: asStr(j['pointsExpireAt']),
            ),
        ledger: mapList(j['ledger'], PointLedgerEntry.fromJson),
      );

  final String retailerCode;

  /// Available points (excludes pending and held).
  final int balance;
  final int pending;
  final int held;
  final String tier;
  final LoyaltyProgram program;
  final List<PointLedgerEntry> ledger;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'retailerCode': retailerCode,
        'balance': balance,
        'pending': pending,
        'held': held,
        'tier': tier,
        'program': program.toJson(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
      };
}

/// Gift `QUA-000`.
class Gift {
  const Gift({
    required this.id,
    required this.code,
    required this.name,
    required this.points,
    required this.stock,
  });

  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
        id: asStr(j['id']),
        code: asStr(j['code']),
        name: asStr(j['name']),
        points: asInt(j['requiredPoints'] ?? j['points']),
        stock: asInt(j['availableQuantity'] ?? j['stock'], 999999),
      );

  final String id;
  final String code;
  final String name;
  final int points;
  final int stock;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'points': points,
        'stock': stock,
      };
}

/// Gift redemption request `DQ-yyMMdd-nn`.
class GiftRedemption {
  const GiftRedemption({
    required this.code,
    required this.giftCode,
    required this.giftName,
    required this.points,
    required this.status,
    this.requestedAt,
  });

  factory GiftRedemption.fromJson(Map<String, dynamic> j) => GiftRedemption(
        code: asStr(j['id'] ?? j['code']),
        giftCode: asStr(j['rewardCode'] ?? j['giftCode']),
        giftName: asStr(j['rewardName'] ?? j['giftName']),
        points: asInt(j['redeemedPoints'] ?? j['points']),
        status: GiftRequestStatus.fromCode(asStrOrNull(j['status'])),
        requestedAt: asDate(j['createdAt'] ?? j['requestedAt']),
      );

  final String code;
  final String giftCode;
  final String giftName;
  final int points;
  final GiftRequestStatus status;
  final DateTime? requestedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'giftCode': giftCode,
        'giftName': giftName,
        'points': points,
        'status': status.code,
        'requestedAt': isoOrNull(requestedAt),
      };
}

String _ledgerDescription(Map<String, dynamic> json) {
  final note = asStr(json['note'] ?? json['description']);
  if (note.isNotEmpty) return note;
  return switch (asStr(json['transactionType'] ?? json['kind'])) {
    'Earned' => 'Cộng điểm đơn hàng',
    'EarnedAdjusted' => 'Điều chỉnh điểm theo giá trị đơn',
    'RedemptionHeld' => 'Giữ điểm đổi quà',
    'RedemptionRejected' => 'Hoàn điểm do từ chối đổi quà',
    'RedemptionCompleted' => 'Hoàn tất đổi quà',
    'Expired' => 'Điểm hết hạn',
    final value => value.isEmpty ? 'Giao dịch điểm' : value,
  };
}
