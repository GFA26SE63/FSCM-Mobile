import 'package:fscm_mobile/data/models/json_utils.dart';

class RetailerOrderEligibility {
  const RetailerOrderEligibility({
    required this.salesUserId,
    required this.retailerId,
    required this.isEligible,
    required this.salesGroupId,
    required this.salesGroupCode,
    required this.retailerStatus,
    required this.creditTermDays,
    required this.reasons,
  });

  factory RetailerOrderEligibility.fromJson(Map<String, dynamic> json) {
    final salesUserId = asStr(json['salesUserId']);
    final retailerId = asStr(json['retailerId']);
    final eligible = json['isEligible'];
    final reasons = json['reasons'];

    if (salesUserId.isEmpty ||
        retailerId.isEmpty ||
        eligible is! bool ||
        reasons is! List ||
        reasons.any((reason) => reason is! String)) {
      throw const FormatException(
        'Phản hồi kiểm tra điều kiện đặt hàng không hợp lệ.',
      );
    }

    return RetailerOrderEligibility(
      salesUserId: salesUserId,
      retailerId: retailerId,
      isEligible: eligible,
      salesGroupId: asStrOrNull(json['salesGroupId']),
      salesGroupCode: asStrOrNull(json['salesGroupCode']),
      retailerStatus: asStr(json['retailerStatus']),
      creditTermDays: asInt(json['creditTermDays']),
      reasons: reasons.cast<String>().toList(growable: false),
    );
  }

  final String salesUserId;
  final String retailerId;
  final bool isEligible;
  final String? salesGroupId;
  final String? salesGroupCode;
  final String retailerStatus;
  final int creditTermDays;
  final List<String> reasons;

  String get denialMessage => reasons.isEmpty
      ? 'Điểm bán hiện chưa đủ điều kiện đặt hàng.'
      : reasons.join('\n');
}
