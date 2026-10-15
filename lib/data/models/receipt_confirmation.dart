import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';

/// Response of `POST /orders/{code}/confirm-receipt`.
class ReceiptConfirmation {
  const ReceiptConfirmation({
    required this.order,
    required this.pointsEarned,
    required this.pointsPending,
  });

  factory ReceiptConfirmation.fromJson(Map<String, dynamic> j) =>
      ReceiptConfirmation(
        order: Order.fromJson(asMap(j['order'])),
        pointsEarned: asInt(j['pointsEarned']),
        pointsPending: asBool(j['pointsPending']),
      );

  final Order order;

  /// Points credited now (COD / prepaid) - 0 for credit orders.
  final int pointsEarned;

  /// True for credit orders: points arrive once the receivable is paid.
  final bool pointsPending;
}
