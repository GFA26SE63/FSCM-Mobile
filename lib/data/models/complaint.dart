import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Complaint `KN-yyMMdd-nn` about a delivered order line.
class Complaint {
  const Complaint({
    required this.code,
    required this.orderCode,
    required this.sku,
    required this.name,
    required this.expectedQty,
    required this.actualQty,
    required this.status,
    this.labelCode = '',
    this.note = '',
    this.createdAt,
    this.response = '',
  });

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        code: asStr(j['code']),
        orderCode: asStr(j['orderCode']),
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        expectedQty: asInt(j['expectedQty']),
        actualQty: asInt(j['actualQty']),
        status: ComplaintStatus.fromCode(asStrOrNull(j['status'])),
        labelCode: asStr(j['labelCode']),
        note: asStr(j['note']),
        createdAt: asDate(j['createdAt']),
        response: asStr(j['response']),
      );

  final String code;
  final String orderCode;
  final String sku;
  final String name;
  final int expectedQty;
  final int actualQty;
  final ComplaintStatus status;
  final String labelCode;
  final String note;
  final DateTime? createdAt;
  final String response;

  int get shortfall => expectedQty - actualQty;
}

/// Request body of `POST /complaints`.
class NewComplaint {
  const NewComplaint({
    required this.orderCode,
    required this.sku,
    required this.labelCode,
    required this.actualQty,
    required this.note,
  });

  final String orderCode;
  final String sku;
  final String labelCode;
  final int actualQty;
  final String note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderCode': orderCode,
        'sku': sku,
        'labelCode': labelCode,
        'actualQty': actualQty,
        'note': note,
      };
}
