import 'package:fscm_mobile/data/models/json_utils.dart';

class SalesOrderQuote {
  const SalesOrderQuote({required this.id, required this.orderId, required this.orderCode, required this.status, required this.totalAmount, required this.expiresAt, required this.version, this.purchaseOrderCode = ''});
  factory SalesOrderQuote.fromJson(Map<String, dynamic> j) => SalesOrderQuote(id: asStr(j['id']), orderId: asStr(j['salesOrderId']), orderCode: asStr(j['orderCode']), status: asStr(j['status']), totalAmount: asInt(j['totalAmount']), expiresAt: asDate(j['expiresAt']), version: asInt(j['version']), purchaseOrderCode: asStr(j['purchaseOrderCode']));
  final String id, orderId, orderCode, status, purchaseOrderCode;
  final int totalAmount, version;
  final DateTime? expiresAt;
}
