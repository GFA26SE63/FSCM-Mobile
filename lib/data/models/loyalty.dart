import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

PointKind _pointKind(Map<String, dynamic> json) {
  final type = asStr(json['kind'] ?? json['transactionType']).toLowerCase();
  if (type.contains('pending')) return PointKind.pending;
  if (type.contains('hold')) return PointKind.held;
  if (type.contains('refund')) return PointKind.refunded;
  if (type.contains('redeem')) return PointKind.redeemed;
  return PointKind.earned;
}

/// Loyalty program `LP-000`: 1 point per [amountPerPoint] (đ) after promotion.
class LoyaltyProgram {
  const LoyaltyProgram({
    required this.code,
    required this.name,
    required this.amountPerPoint,
    this.expiryText = '',
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> j) => LoyaltyProgram(
        code: asStr(j['code']),
        name: asStr(j['name']),
        amountPerPoint: asInt(j['amountPerPoint'], 100000),
        expiryText: asStr(j['expiryText']),
      );

  final String code;
  final String name;
  final int amountPerPoint;
  final String expiryText;

  Map<String, dynamic> toJson() => <String, dynamic>{
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
    this.transactionType = '',
    this.source = '',
    this.balanceAfter,
  });

  factory PointLedgerEntry.fromJson(Map<String, dynamic> j) => PointLedgerEntry(
        date: asDate(j['createdAt'] ?? j['date']),
        description: asStr(j['note'], asStr(j['description'], asStr(j['transactionType']))),
        points: asInt(j['points']),
        kind: _pointKind(j),
        orderCode: asStr(j['orderCode']),
        transactionType: asStr(j['transactionType']),
        source: asStr(j['orderCode'], asStr(j['salesOrderId'])),
        balanceAfter: j['balanceAfter'] == null ? null : asInt(j['balanceAfter']),
      );

  final DateTime? date;
  final String description;

  /// Signed points (negative for redemptions / holds).
  final int points;
  final PointKind kind;
  final String orderCode;
  final String transactionType;
  final String source;
  final int? balanceAfter;

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

  factory LoyaltyAccount.fromJson(Map<String, dynamic> j) => LoyaltyAccount(
        retailerCode: asStr(j['retailerCode']),
        balance: asInt(j['availablePoints'] ?? j['balance']),
        pending: asInt(j['pendingPoints'] ?? j['pending']),
        held: asInt(j['heldPoints'] ?? j['held']),
        tier: asStr(j['programName'], asStr(j['tier'])),
        program: LoyaltyProgram.fromJson(<String, dynamic>{
          ...asMap(j['program']),
          'code': asStr(j['programCode'], asMap(j['program'])['code']),
          'name': asStr(j['programName'], asMap(j['program'])['name']),
          'expiryText': asStr(j['pointsExpireAt']),
        }),
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
    this.id = '',
    required this.code,
    required this.name,
    required this.points,
    required this.stock,
    this.description = '',
    this.imageUrl,
  });

  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
        id: asStr(j['id']),
        code: asStr(j['code']),
        name: asStr(j['name']),
        points: asInt(j['requiredPoints'] ?? j['points']),
        stock: asInt(j['availableQuantity'] ?? j['stock']),
        description: asStr(j['description']),
        imageUrl: asStrOrNull(j['imageUrl']),
      );

  final String id;
  final String code;
  final String name;
  final int points;
  final int stock;
  final String description;
  final String? imageUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'points': points,
        'stock': stock,
        'description': description,
        'imageUrl': imageUrl,
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
        code: asStr(j['id'], asStr(j['code'])),
        giftCode: asStr(j['rewardCode'], asStr(j['giftCode'])),
        giftName: asStr(j['rewardName'], asStr(j['giftName'])),
        points: asInt(j['redeemedPoints'], asInt(j['points'])),
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
