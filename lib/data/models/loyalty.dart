import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

Never invalidLoyaltyResponse() => throw const ApiException(
    kind: ApiErrorKind.server,
    message: 'Phản hồi thẻ hoặc sổ điểm thiếu dữ liệu hợp lệ.');

String _requiredText(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is! String || value.isEmpty) {
    invalidLoyaltyResponse();
  }
  return value;
}

int _requiredInt(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    invalidLoyaltyResponse();
  }
  return value.toInt();
}

DateTime _requiredDate(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is! String || DateTime.tryParse(value) == null) {
    invalidLoyaltyResponse();
  }
  return DateTime.parse(value);
}

DateTime? _optionalDate(Map<String, dynamic> j, String key) {
  if (!j.containsKey(key)) {
    invalidLoyaltyResponse();
  }
  return j[key] == null ? null : _requiredDate(j, key);
}

/// Conversion rate is decimal in the API, never rounded to an integer.
class LoyaltyProgram {
  const LoyaltyProgram({
    required this.id,
    required this.code,
    required this.name,
    required this.amountPerPoint,
    required this.isActive,
    required this.startAt,
    required this.endAt,
    this.expiryText = '',
  });

  factory LoyaltyProgram.fromJson(Map<String, dynamic> j) {
    final rate = j['spendAmountPerPoint'];
    if (rate is! num || !rate.isFinite || rate <= 0 || j['isActive'] is! bool) {
      invalidLoyaltyResponse();
    }
    final expiry = _optionalDate(j, 'pointsExpireAt');
    return LoyaltyProgram(
      id: _requiredText(j, 'id'),
      code: _requiredText(j, 'code'),
      name: _requiredText(j, 'name'),
      amountPerPoint: rate,
      isActive: j['isActive'] as bool,
      startAt: _requiredDate(j, 'startAt'),
      endAt: _requiredDate(j, 'endAt'),
      expiryText: expiry?.toIso8601String() ?? '',
    );
  }

  final String id, code, name;
  final num amountPerPoint;
  final bool isActive;
  final DateTime startAt, endAt;
  final String expiryText;

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'spendAmountPerPoint': amountPerPoint,
        'isActive': isActive,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'pointsExpireAt': expiryText.isEmpty ? null : expiryText,
      };
}

class PointLedgerEntry {
  const PointLedgerEntry({
    required this.id,
    required this.date,
    required this.description,
    required this.points,
    required this.kind,
    required this.transactionType,
    required this.balanceAfter,
    this.orderId,
    this.orderCode,
    this.redemptionId,
    this.redemptionStatus,
  });

  factory PointLedgerEntry.fromJson(Map<String, dynamic> j) {
    final type = _requiredText(j, 'transactionType');
    return PointLedgerEntry(
      id: _requiredText(j, 'transactionId'),
      date: _requiredDate(j, 'createdAt'),
      description: _ledgerDescription(j),
      points: _requiredInt(j, 'points'),
      kind: PointKind.fromCode(type),
      transactionType: type,
      balanceAfter: _requiredInt(j, 'balanceAfter'),
      orderId: asStrOrNull(j['salesOrderId']),
      orderCode: asStrOrNull(j['orderCode']),
      redemptionId: asStrOrNull(j['redemptionId']),
      redemptionStatus: asStrOrNull(j['redemptionStatus']),
    );
  }

  final String id, description, transactionType;
  final DateTime date;
  final int points, balanceAfter;
  final PointKind kind;
  final String? orderId, orderCode, redemptionId, redemptionStatus;

  Map<String, dynamic> toJson() => {
        'transactionId': id,
        'createdAt': date.toIso8601String(),
        'note': description,
        'points': points,
        'transactionType': transactionType,
        'balanceAfter': balanceAfter,
        'salesOrderId': orderId,
        'orderCode': orderCode,
        'redemptionId': redemptionId,
        'redemptionStatus': redemptionStatus,
      };
}

/// GET /loyalty/cards/me. Use the server totals; do not recalculate the ledger.
class LoyaltyAccount {
  const LoyaltyAccount({
    required this.retailerId,
    required this.retailerCode,
    required this.retailerName,
    required this.balance,
    required this.pending,
    required this.held,
    required this.expired,
    required this.ledger,
    required this.programId,
    required this.programCode,
    required this.programName,
    required this.pointsExpireAt,
    this.program,
  });

  factory LoyaltyAccount.fromJson(Map<String, dynamic> j,
      {LoyaltyProgram? program}) {
    for (final key in [
      'programId',
      'programCode',
      'programName',
      'pointsExpireAt'
    ]) {
      if (!j.containsKey(key)) {
        invalidLoyaltyResponse();
      }
    }
    final programId = asStrOrNull(j['programId']);
    if (program != null && program.id != programId) {
      invalidLoyaltyResponse();
    }
    final rawLedger = j['ledger'];
    if (rawLedger is! List<dynamic>) {
      invalidLoyaltyResponse();
    }
    final ledger = rawLedger.map((row) {
      if (row is! Map<String, dynamic>) {
        invalidLoyaltyResponse();
      }
      return PointLedgerEntry.fromJson(row);
    }).toList(growable: false);
    return LoyaltyAccount(
      retailerId: _requiredText(j, 'retailerId'),
      retailerCode: _requiredText(j, 'retailerCode'),
      retailerName: _requiredText(j, 'retailerName'),
      balance: _requiredInt(j, 'availablePoints'),
      pending: _requiredInt(j, 'pendingPoints'),
      held: _requiredInt(j, 'heldPoints'),
      expired: _requiredInt(j, 'expiredPoints'),
      ledger: ledger,
      program: program,
      programId: programId,
      programCode: asStrOrNull(j['programCode']),
      programName: asStrOrNull(j['programName']),
      pointsExpireAt: _optionalDate(j, 'pointsExpireAt'),
    );
  }

  final String retailerId, retailerCode, retailerName;
  final int balance, pending, held, expired;
  final List<PointLedgerEntry> ledger;
  final String? programId, programCode, programName;
  final DateTime? pointsExpireAt;
  final LoyaltyProgram? program;

  /// Negative balance from the server blocks new redemption, not ledger access.
  bool get hasNegativeBalance => balance < 0;

  Map<String, dynamic> toJson() => {
        'retailerId': retailerId,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'availablePoints': balance,
        'pendingPoints': pending,
        'heldPoints': held,
        'expiredPoints': expired,
        'programId': programId,
        'programCode': programCode,
        'programName': programName,
        'pointsExpireAt': pointsExpireAt?.toIso8601String(),
        'ledger': ledger.map((entry) => entry.toJson()).toList(),
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
    this.programId,
    this.description,
    this.imageUrl,
    this.isActive = true,
  });

  factory Gift.fromJson(Map<String, dynamic> j) {
    if (!j.containsKey('availableQuantity') || j['isActive'] is! bool) {
      invalidLoyaltyResponse();
    }
    final points = _requiredInt(j, 'requiredPoints');
    final stock = j['availableQuantity'] == null ? null : _requiredInt(j, 'availableQuantity');
    if (points <= 0 || (stock != null && stock < 0)) {
      invalidLoyaltyResponse();
    }
    return Gift(id: _requiredText(j, 'id'), code: _requiredText(j, 'code'),
      name: _requiredText(j, 'name'), programId: _requiredText(j, 'loyaltyProgramId'),
      points: points, stock: stock, description: asStrOrNull(j['description']),
      imageUrl: asStrOrNull(j['imageUrl']), isActive: j['isActive'] as bool);
  }

  final String id;
  final String code;
  final String name;
  final int points;
  final int? stock;
  final String? programId, description, imageUrl;
  final bool isActive;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'requiredPoints': points,
        'availableQuantity': stock,
        'loyaltyProgramId': programId,
        'description': description,
        'imageUrl': imageUrl,
        'isActive': isActive,
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
    this.quantity,
    this.quantityIsEstimated = false,
    this.clientRequestId,
  });

  factory GiftRedemption.fromJson(Map<String, dynamic> j) {
    if (j['quantityIsEstimated'] is! bool || _requiredInt(j, 'quantity') <= 0 ||
        _requiredInt(j, 'redeemedPoints') < 0) {
      invalidLoyaltyResponse();
    }
    return GiftRedemption(
        code: _requiredText(j, 'id'),
        giftCode: _requiredText(j, 'rewardCode'),
        giftName: _requiredText(j, 'rewardName'),
        points: _requiredInt(j, 'redeemedPoints'),
        status: GiftRequestStatus.fromCode(_requiredText(j, 'status')),
        requestedAt: _requiredDate(j, 'createdAt'),
        quantity: _requiredInt(j, 'quantity'),
        quantityIsEstimated: j['quantityIsEstimated'] as bool,
        clientRequestId: _requiredText(j, 'clientRequestId'),
      );
  }

  final String code;
  final String giftCode;
  final String giftName;
  final int points;
  final GiftRequestStatus status;
  final DateTime? requestedAt;
  final int? quantity;
  final bool quantityIsEstimated;
  final String? clientRequestId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': code,
        'rewardCode': giftCode,
        'rewardName': giftName,
        'redeemedPoints': points,
        'status': status.code,
        'createdAt': isoOrNull(requestedAt),
        'quantity': quantity,
        'quantityIsEstimated': quantityIsEstimated,
        'clientRequestId': clientRequestId,
      };
}

String _ledgerDescription(Map<String, dynamic> json) {
  final note = asStr(json['note'] ?? json['description']);
  if (note.isNotEmpty) return note;
  return switch (asStr(json['transactionType'] ?? json['kind'])) {
    'Earned' => 'Cộng điểm đơn hàng',
    'PendingEarn' || 'Pending' => 'Điểm chờ đủ điều kiện cộng',
    'PendingEarnCancelled' => 'Hủy điểm chờ cộng',
    'EarnedAdjusted' => 'Điều chỉnh điểm theo giá trị đơn',
    'RedemptionHeld' => 'Giữ điểm đổi quà',
    'RedemptionRejected' => 'Hoàn điểm do từ chối đổi quà',
    'RedemptionCompleted' => 'Hoàn tất đổi quà',
    'Expired' => 'Điểm hết hạn',
    final value => value.isEmpty ? 'Giao dịch điểm' : value,
  };
}
