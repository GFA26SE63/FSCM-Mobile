import 'package:fscm_mobile/data/models/json_utils.dart';

class OfflineExpectedCondition {
  const OfflineExpectedCondition({
    required this.productId,
    required this.expectedBaseUnitPrice,
    required this.expectedMlorVersion,
    required this.expectedMlorRatio,
  });

  factory OfflineExpectedCondition.fromJson(
    Map<String, dynamic> json,
  ) =>
      OfflineExpectedCondition(
        productId: asStr(json['productId']),
        expectedBaseUnitPrice:
            asDouble(json['expectedBaseUnitPrice'], double.nan),
        expectedMlorVersion: asInt(json['expectedMlorVersion']),
        expectedMlorRatio: asDouble(json['expectedMlorRatio'], double.nan),
      );

  final String productId;
  final num expectedBaseUnitPrice;
  final int expectedMlorVersion;
  final double expectedMlorRatio;

  bool get isValid =>
      productId.isNotEmpty &&
      expectedBaseUnitPrice.isFinite &&
      expectedBaseUnitPrice >= 0 &&
      expectedMlorVersion >= 1 &&
      expectedMlorRatio.isFinite &&
      expectedMlorRatio > 0 &&
      expectedMlorRatio < 1;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'expectedBaseUnitPrice': expectedBaseUnitPrice,
        'expectedMlorVersion': expectedMlorVersion,
        'expectedMlorRatio': expectedMlorRatio,
      };
}
