import 'package:fscm_mobile/data/models/loyalty.dart';

/// Immutable body and key for one explicitly confirmed redemption.
class RedemptionAttempt {
  const RedemptionAttempt(
      {required this.ownerId,
      required this.retailerId,
      required this.rewardId,
      required this.giftName,
      required this.quantity,
      required this.unitPoints,
      required this.operationKey,
      this.mayHaveSucceeded = false});

  final String ownerId, retailerId, rewardId, giftName, operationKey;
  final int quantity, unitPoints;
  final bool mayHaveSucceeded;
  int get totalPoints => quantity * unitPoints;

  factory RedemptionAttempt.fromJson(Map<String, dynamic> json) {
    for (final key in [
      'ownerId',
      'retailerId',
      'rewardId',
      'giftName',
      'operationKey'
    ]) {
      if (json[key] is! String || (json[key] as String).isEmpty) {
        invalidLoyaltyResponse();
      }
    }
    for (final key in ['quantity', 'unitPoints']) {
      if (json[key] is! int || (json[key] as int) <= 0) {
        invalidLoyaltyResponse();
      }
    }
    return RedemptionAttempt(
        ownerId: json['ownerId'] as String,
        retailerId: json['retailerId'] as String,
        rewardId: json['rewardId'] as String,
        giftName: json['giftName'] as String,
        quantity: json['quantity'] as int,
        unitPoints: json['unitPoints'] as int,
        operationKey: json['operationKey'] as String,
        mayHaveSucceeded: json['mayHaveSucceeded'] == true);
  }

  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'retailerId': retailerId,
        'rewardId': rewardId,
        'giftName': giftName,
        'quantity': quantity,
        'unitPoints': unitPoints,
        'operationKey': operationKey,
        'mayHaveSucceeded': mayHaveSucceeded
      };
}
