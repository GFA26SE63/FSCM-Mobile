import 'package:fscm_mobile/data/models/json_utils.dart';

class SalesOrderQuote {
  const SalesOrderQuote({
    required this.id,
    required this.salesOrderId,
    required this.orderCode,
    required this.status,
    required this.totalAmount,
    required this.expiresAt,
    required this.version,
  });

  factory SalesOrderQuote.fromJson(Map<String, dynamic> json) => SalesOrderQuote(
        id: asStr(json['id']),
        salesOrderId: asStr(json['salesOrderId']),
        orderCode: asStr(json['orderCode']),
        status: asStr(json['status']),
        totalAmount: asInt(json['totalAmount']),
        expiresAt: asDate(json['expiresAt']) ?? DateTime.now(),
        version: asInt(json['version']),
      );

  final String id;
  final String salesOrderId;
  final String orderCode;
  final String status;
  final int totalAmount;
  final DateTime expiresAt;
  final int version;

  bool get canDecide => status == 'Issued' && expiresAt.isAfter(DateTime.now());
}

class PayOsCheckout {
  const PayOsCheckout({required this.checkoutUrl, required this.qrCode});

  factory PayOsCheckout.fromJson(Map<String, dynamic> json) => PayOsCheckout(
        checkoutUrl: asStr(json['checkoutUrl']),
        qrCode: asStr(json['qrCode']),
      );

  final String checkoutUrl;
  final String qrCode;
}
