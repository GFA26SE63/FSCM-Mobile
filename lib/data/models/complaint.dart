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
    required this.issueType,
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
        name: asStr(j['name'] ?? j['productName']),
        expectedQty: asInt(j['expectedQty'] ?? j['expectedQuantity']),
        actualQty: asInt(j['actualQty'] ?? j['actualQuantity']),
        issueType: asStr(j['issueType']),
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
  final String issueType;
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
    required this.issueType,
    required this.note,
    this.shipmentId,
    this.allocationId,
  });

  final String orderCode;
  final String sku;
  final String labelCode;
  final int actualQty;
  final String issueType;
  final String note;

  final String? shipmentId;
  final String? allocationId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderCode': orderCode,
        'sku': sku,
        'labelCode': labelCode,
        'actualQty': actualQty,
        'issueType': issueType,
        'note': note,
        if (shipmentId != null) 'shipmentId': shipmentId,
        if (allocationId != null) 'allocationId': allocationId,
      };
}

class ComplaintTarget {
  const ComplaintTarget(
      {required this.shipmentId,
      required this.shipmentCode,
      required this.allocationId,
      required this.sku,
      required this.productName,
      required this.batchCode,
      required this.labelCode,
      required this.expectedQuantity});
  factory ComplaintTarget.fromJson(Map<String, dynamic> j) => ComplaintTarget(
      shipmentId: asStr(j['shipmentId']),
      shipmentCode: asStr(j['shipmentCode']),
      allocationId: asStr(j['allocationId']),
      sku: asStr(j['sku']),
      productName: asStr(j['productName']),
      batchCode: asStr(j['batchCode']),
      labelCode: asStr(j['labelCode']),
      expectedQuantity: asInt(j['expectedQuantity']));
  final String shipmentId,
      shipmentCode,
      allocationId,
      sku,
      productName,
      batchCode,
      labelCode;
  final int expectedQuantity;
}
