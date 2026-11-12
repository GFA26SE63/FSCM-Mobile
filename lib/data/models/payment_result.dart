import 'package:fscm_mobile/data/models/json_utils.dart';

/// Authoritative payment state returned by Backend:
/// `GET /api/v1/payments/orders/{orderId}`
class PaymentResult {
  const PaymentResult({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.amount,
    required this.outstandingAmount,
    required this.confirmedAmount,
    required this.orderPaymentMethod,
    this.payOsOrderCode,
    this.payOsPaymentLinkId,
    this.payOsCheckoutUrl,
    this.payOsQrCode,
    this.payOsLinkStatus,
    this.payOsExpiredAt,
    required this.version,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
        id: asStr(json['id']),
        orderId: asStr(json['orderId']),
        orderCode: asStr(json['orderCode']),
        status: asStr(json['status']),
        amount: asDouble(json['amount']),
        outstandingAmount: asDouble(json['outstandingAmount']),
        confirmedAmount: asDouble(json['confirmedAmount']),
        orderPaymentMethod: asStr(json['orderPaymentMethod'] ?? json['method']),
        payOsOrderCode: json['payOsOrderCode'] != null
            ? asInt(json['payOsOrderCode'])
            : null,
        payOsPaymentLinkId: asStrOrNull(json['payOsPaymentLinkId']),
        payOsCheckoutUrl: asStrOrNull(json['payOsCheckoutUrl']),
        payOsQrCode: asStrOrNull(json['payOsQrCode']),
        payOsLinkStatus: asStrOrNull(json['payOsLinkStatus']),
        payOsExpiredAt: json['payOsExpiredAt'] != null
            ? asInt(json['payOsExpiredAt'])
            : null,
        version: asInt(json['version']),
      );

  final String id;
  final String orderId;
  final String orderCode;
  final String status;
  final num amount;
  final num outstandingAmount;
  final num confirmedAmount;
  final String orderPaymentMethod;
  final int? payOsOrderCode;
  final String? payOsPaymentLinkId;
  final String? payOsCheckoutUrl;
  final String? payOsQrCode;
  final String? payOsLinkStatus;
  final int? payOsExpiredAt;
  final int version;

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isUnpaid => status.toLowerCase() == 'unpaid';
  bool get isOverdue => status.toLowerCase() == 'overdue';
  bool get isPartiallyPaid => status.toLowerCase() == 'partiallypaid';
}

