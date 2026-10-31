import 'package:fscm_mobile/data/models/json_utils.dart';

class AllocationRunResultLine {
  const AllocationRunResultLine({
    required this.sku,
    required this.lineNumber,
    required this.orderedQuantity,
    required this.allocatedQuantity,
    required this.shortageQuantity,
    required this.outcome,
    required this.reason,
    required this.finalAmount,
  });

  factory AllocationRunResultLine.fromJson(Map<String, dynamic> json) =>
      AllocationRunResultLine(
        sku: asStr(json['sku']),
        lineNumber: asInt(json['lineNumber']),
        orderedQuantity: asDouble(json['orderedQuantity']),
        allocatedQuantity: asDouble(json['allocatedQuantity']),
        shortageQuantity: asDouble(json['shortageQuantity']),
        outcome: asStr(json['outcome']),
        reason: asStr(json['reason']),
        finalAmount: asDouble(json['finalAmount']),
      );

  final String sku;
  final int lineNumber;
  final double orderedQuantity;
  final double allocatedQuantity;
  final double shortageQuantity;
  final String outcome;
  final String reason;
  final double finalAmount;
}

class AllocationRunResult {
  const AllocationRunResult({
    required this.orderCode,
    required this.runCode,
    required this.businessDate,
    required this.approvedAt,
    required this.planVersionNumber,
    required this.isFulfilled,
    required this.shortageReason,
    required this.hasReservedStock,
    required this.canResubmitKeepingPriority,
    required this.finalAmount,
    required this.lines,
  });

  factory AllocationRunResult.fromJson(Map<String, dynamic> json) =>
      AllocationRunResult(
        orderCode: asStr(json['orderCode']),
        runCode: asStr(json['runCode']),
        businessDate: asStr(json['businessDate']),
        approvedAt: asDate(json['approvedAt']),
        planVersionNumber: asInt(json['planVersionNumber']),
        isFulfilled: asBool(json['isFulfilled']),
        shortageReason: asStr(json['shortageReason']),
        hasReservedStock: asBool(json['hasReservedStock']),
        canResubmitKeepingPriority: asBool(json['canResubmitKeepingPriority']),
        finalAmount: asDouble(json['finalAmount']),
        lines: mapList(json['lines'], AllocationRunResultLine.fromJson),
      );

  final String orderCode;
  final String runCode;
  final String businessDate;
  final DateTime? approvedAt;
  final int planVersionNumber;
  final bool isFulfilled;
  final String shortageReason;
  final bool hasReservedStock;
  final bool canResubmitKeepingPriority;
  final double finalAmount;
  final List<AllocationRunResultLine> lines;
}
