import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

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
  });

  factory PointLedgerEntry.fromJson(Map<String, dynamic> j) => PointLedgerEntry(
        date: asDate(j['date']),
        description: asStr(j['description']),
        points: asInt(j['points']),
        kind: PointKind.fromCode(asStrOrNull(j['kind'])),
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

  factory LoyaltyAccount.fromJson(Map<String, dynamic> j) => LoyaltyAccount(
        retailerCode: asStr(j['retailerCode']),
        balance: asInt(j['balance']),
        pending: asInt(j['pending']),
        held: asInt(j['held']),
        tier: asStr(j['tier']),
        program: LoyaltyProgram.fromJson(asMap(j['program'])),
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
    required this.code,
    required this.name,
    required this.points,
    required this.stock,
  });

  factory Gift.fromJson(Map<String, dynamic> j) => Gift(
        code: asStr(j['code']),
        name: asStr(j['name']),
        points: asInt(j['points']),
        stock: asInt(j['stock']),
      );

  final String code;
  final String name;
  final int points;
  final int stock;

  Map<String, dynamic> toJson() => <String, dynamic>{
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
        code: asStr(j['code']),
        giftCode: asStr(j['giftCode']),
        giftName: asStr(j['giftName']),
        points: asInt(j['points']),
        status: GiftRequestStatus.fromCode(asStrOrNull(j['status'])),
        requestedAt: asDate(j['requestedAt']),
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
