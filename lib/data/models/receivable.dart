import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Receivable of a credit order (SPEC: partial credit only, single full
/// collection, due = delivered date + term).
class Receivable {
  const Receivable({
    required this.orderId,
    required this.orderCode,
    required this.retailerCode,
    required this.retailerName,
    required this.amount,
    required this.outstandingAmount,
    required this.status,
    this.deliveredAt,
    this.dueDate,
    this.term = 0,
    this.paidAt,
    this.version = 0,
  });

  factory Receivable.fromJson(Map<String, dynamic> j) => Receivable(
        orderId: asStr(j['orderId']),
        orderCode: asStr(j['orderCode']),
        retailerCode: asStr(j['retailerCode']),
        retailerName: asStr(j['retailerName']),
        amount: asInt(j['adjustedAmount'] ?? j['amount']),
        outstandingAmount:
            asInt(j['outstandingAmount'] ?? j['adjustedAmount'] ?? j['amount']),
        status: ReceivableStatus.fromCode(asStrOrNull(j['status'])),
        deliveredAt: asDate(j['deliveredDate'] ?? j['deliveredAt']),
        dueDate: asDate(j['dueDate']),
        term: asInt(j['creditTermDays'] ?? j['term']),
        paidAt: asDate(j['paidDate'] ?? j['paidAt']),
        version: asInt(j['version']),
      );

  final String orderId;
  final String orderCode;
  final String retailerCode;
  final String retailerName;
  final int amount;
  final int outstandingAmount;
  final ReceivableStatus status;
  final DateTime? deliveredAt;
  final DateTime? dueDate;
  final int term;
  final DateTime? paidAt;
  final int version;

  bool get isPaid => status == ReceivableStatus.paid;
  bool get isOverdue => status == ReceivableStatus.overdue;

  /// Days past due (positive) or until due (negative) relative to [now].
  int daysOverdue(DateTime now) {
    final due = dueDate;
    if (due == null) return 0;
    final a = DateTime(due.year, due.month, due.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  Receivable copyWith({ReceivableStatus? status, DateTime? paidAt}) =>
      Receivable(
        orderId: orderId,
        orderCode: orderCode,
        retailerCode: retailerCode,
        retailerName: retailerName,
        amount: amount,
        outstandingAmount: outstandingAmount,
        status: status ?? this.status,
        deliveredAt: deliveredAt,
        dueDate: dueDate,
        term: term,
        paidAt: paidAt ?? this.paidAt,
        version: version,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderId': orderId,
        'orderCode': orderCode,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'amount': amount,
        'outstandingAmount': outstandingAmount,
        'status': status.code,
        'deliveredAt': isoOrNull(deliveredAt),
        'dueDate': isoOrNull(dueDate),
        'term': term,
        'paidAt': isoOrNull(paidAt),
        'version': version,
      };
}
