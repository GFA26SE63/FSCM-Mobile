import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/core/utils/clock.dart';

class SalesOrderQuote {
  const SalesOrderQuote({
    required this.id,
    required this.salesOrderId,
    required this.orderCode,
    required this.status,
    required this.totalAmount,
    required this.expiresAt,
    required this.version,
    this.revisionNumber = 0,
    this.purchaseOrderCode,
    this.rejectionReason,
  });

  factory SalesOrderQuote.fromJson(Map<String, dynamic> json) =>
      SalesOrderQuote(
        id: asStr(json['id']),
        salesOrderId: asStr(json['salesOrderId']),
        orderCode: asStr(json['orderCode']),
        status: asStr(json['status']),
        totalAmount: asDouble(json['totalAmount']),
        expiresAt: asDate(json['expiresAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        version: asInt(json['version']),
        revisionNumber: asInt(json['revisionNumber']),
        purchaseOrderCode: asStrOrNull(json['purchaseOrderCode']),
        rejectionReason: asStrOrNull(json['rejectionReason']),
      );

  final String id;
  final String salesOrderId;
  final String orderCode;
  final String status;
  final num totalAmount;
  final DateTime expiresAt;
  final int version;
  final int revisionNumber;
  final String? purchaseOrderCode;
  final String? rejectionReason;

  bool canDecideAt(DateTime at) =>
      id.isNotEmpty &&
      salesOrderId.isNotEmpty &&
      version >= 1 &&
      status == 'Issued' &&
      expiresAt.isAfter(at);

  bool get canDecide => canDecideAt(AppClock.now());

  static SalesOrderQuote? latestForOrder(
      Iterable<SalesOrderQuote> rows, String orderId) {
    final scoped = rows.where((quote) => quote.salesOrderId == orderId).toList()
      ..sort((a, b) {
        final revision = b.revisionNumber.compareTo(a.revisionNumber);
        return revision != 0 ? revision : b.version.compareTo(a.version);
      });
    return scoped.isEmpty ? null : scoped.first;
  }
}

class PayOsCheckout {
  const PayOsCheckout({
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.checkoutUrl,
    required this.qrCode,
    required this.status,
  });

  factory PayOsCheckout.fromJson(Map<String, dynamic> json) => PayOsCheckout(
        paymentId: asStr(json['paymentId']),
        orderId: asStr(json['orderId']),
        amount: asDouble(json['amount']),
        checkoutUrl: asStr(json['checkoutUrl']),
        qrCode: asStr(json['qrCode']),
        status: asStr(json['status']),
      );

  final String paymentId;
  final String orderId;
  final num amount;
  final String checkoutUrl;
  final String qrCode;
  final String status;
}
