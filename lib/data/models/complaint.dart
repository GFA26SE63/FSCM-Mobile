import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Complaint `KN-yyMMdd-nn` about a delivered order line.
class Complaint {
  const Complaint({
    this.id = '',
    this.reviewStatus = '',
    this.resolutionType,
    this.evidenceRequestReason = '',
    this.adjustmentAmount = 0,
    this.finalUnitPrice = 0,
    this.requestType = 'Complaint',
    this.settlementMethod = 'DebtOffset',
    this.approvedSettlementMethod = '',
    this.requestedQuantity = 0,
    this.approvedQuantity,
    this.handledQuantity,
    this.physicalHandlingCompleted = false,
    this.financialAdjustmentApplied = false,
    this.debtOffsetAmount = 0,
    this.refundAmount = 0,
    this.refundId = '',
    this.documents = const [],
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
        id: asStr(j['id']),
        reviewStatus: asStr(j['reviewStatus']),
        resolutionType: asStrOrNull(j['resolutionType']),
        evidenceRequestReason: asStr(j['evidenceRequestReason']),
        adjustmentAmount: asDouble(j['adjustmentAmount']),
        finalUnitPrice: asDouble(j['finalUnitPrice']),
        requestType: asStr(j['requestType']).isEmpty
            ? 'Complaint'
            : asStr(j['requestType']),
        settlementMethod: asStr(j['settlementMethod']),
        approvedSettlementMethod: asStr(j['approvedSettlementMethod']),
        requestedQuantity: asInt(j['requestedQuantity']),
        approvedQuantity:
            j['approvedQuantity'] == null ? null : asInt(j['approvedQuantity']),
        handledQuantity:
            j['handledQuantity'] == null ? null : asInt(j['handledQuantity']),
        physicalHandlingCompleted: j['physicalHandlingCompleted'] == true,
        financialAdjustmentApplied: j['financialAdjustmentApplied'] == true,
        debtOffsetAmount: asDouble(j['debtOffsetAmount']),
        refundAmount: asDouble(j['refundAmount']),
        refundId: asStr(j['refundId']),
        documents: asMapList(j['documents']),
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

  final String id;

  /// Raw backend status: Submitted | UnderReview | Approved | Rejected | Resolved.
  final String reviewStatus;

  /// Replacement or FinancialAdjustment once an admin approved the claim.
  final String? resolutionType;
  final String evidenceRequestReason;
  final double adjustmentAmount;
  final double finalUnitPrice;
  final String requestType,
      settlementMethod,
      approvedSettlementMethod,
      refundId;
  final int requestedQuantity;
  final int? approvedQuantity, handledQuantity;
  final bool physicalHandlingCompleted, financialAdjustmentApplied;
  final double debtOffsetAmount, refundAmount;
  final List<Map<String, dynamic>> documents;
  String get typeText => requestType == 'Return'
      ? 'Trả hàng'
      : requestType == 'DamagedCollection'
          ? 'Thu hồi hàng hỏng'
          : 'Khiếu nại đơn hàng';
  String get settlementText => _settlementLabel(settlementMethod);
  String get approvedSettlementText =>
      _settlementLabel(approvedSettlementMethod);
  static String _settlementLabel(String method) => method == 'CashRefund'
      ? 'Hoàn tiền'
      : method == 'None'
          ? 'Chỉ thu hồi, không bồi hoàn'
          : 'Cấn trừ công nợ';
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

  /// Admin / operator asked for more evidence and the claim is still open.
  bool get needsEvidence => reviewStatus == 'UnderReview';

  /// Evidence can be added while the claim has no final decision.
  bool get acceptsEvidence =>
      status == ComplaintStatus.open || reviewStatus == 'UnderReview';

  /// The retailer can withdraw a claim until it is approved or rejected.
  bool get canCancel =>
      reviewStatus == 'Submitted' || reviewStatus == 'UnderReview';

  bool get isRefund => resolutionType == 'FinancialAdjustment';

  String get statusText {
    if (needsEvidence) return 'Cần bổ sung bằng chứng';
    if (status == ComplaintStatus.rejected) return 'Bị từ chối';
    if (status == ComplaintStatus.cancelled) return 'Đã hủy';
    if (reviewStatus == 'Resolved' || status == ComplaintStatus.resolved) {
      return 'Đã xử lý xong';
    }
    if (status == ComplaintStatus.approved) {
      return physicalHandlingCompleted
          ? 'Đã duyệt · chờ chốt tài chính'
          : 'Đã duyệt · chờ xử lý hàng';
    }
    return 'Đang chờ xem xét';
  }

  StatusTone get statusTone => needsEvidence ? StatusTone.warning : status.tone;
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
    this.requestType = 'Complaint',
    this.settlementMethod = 'DebtOffset',
    this.affectedQuantity,
    this.requiresCollection = false,
  });

  final String orderCode;
  final String sku;
  final String labelCode;
  final int actualQty;
  final String issueType;
  final String note;
  final String requestType, settlementMethod;
  final int? affectedQuantity;
  final bool requiresCollection;

  final String? shipmentId;
  final String? allocationId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderCode': orderCode,
        'sku': sku,
        'labelCode': labelCode,
        'actualQty': actualQty,
        'issueType': issueType,
        'note': note,
        'requestType': requestType,
        'settlementMethod': settlementMethod,
        if (affectedQuantity != null) 'affectedQuantity': affectedQuantity,
        'requiresCollection': requiresCollection,
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
      required this.expectedQuantity,
      this.receivedQuantity,
      this.remainingClaimableQuantity,
      this.remainingReturnableQuantity});
  factory ComplaintTarget.fromJson(Map<String, dynamic> j) => ComplaintTarget(
      shipmentId: asStr(j['shipmentId']),
      shipmentCode: asStr(j['shipmentCode']),
      allocationId: asStr(j['allocationId']),
      sku: asStr(j['sku']),
      productName: asStr(j['productName']),
      batchCode: asStr(j['batchCode']),
      labelCode: asStr(j['labelCode']),
      expectedQuantity: asInt(j['expectedQuantity']),
      receivedQuantity:
          j['receivedQuantity'] == null ? null : asInt(j['receivedQuantity']),
      remainingClaimableQuantity: j['remainingClaimableQuantity'] == null
          ? null
          : asInt(j['remainingClaimableQuantity']),
      remainingReturnableQuantity: j['remainingReturnableQuantity'] == null
          ? null
          : asInt(j['remainingReturnableQuantity']));
  final String shipmentId,
      shipmentCode,
      allocationId,
      sku,
      productName,
      batchCode,
      labelCode;
  final int expectedQuantity;
  final int? receivedQuantity,
      remainingClaimableQuantity,
      remainingReturnableQuantity;
}

/// One evidence image of a claim; [url] is a short-lived read URL.
class ComplaintEvidence {
  const ComplaintEvidence(
      {required this.id,
      required this.fileName,
      required this.url,
      this.uploadedAt});

  factory ComplaintEvidence.fromJson(Map<String, dynamic> j) =>
      ComplaintEvidence(
          id: asStr(j['id']),
          fileName: asStr(j['fileName']),
          url: asStr(j['url']),
          uploadedAt: asDate(j['uploadedAt']));

  final String id, fileName, url;
  final DateTime? uploadedAt;
}
