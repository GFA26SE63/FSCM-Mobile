import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

class PickingLine {
  const PickingLine({
    required this.index,
    required this.sku,
    required this.name,
    required this.batchCode,
    required this.need,
    this.expiry,
    this.location = '',
    this.picked = 0,
    this.suggestedLabel = '',
    this.outLabel = '',
  });

  factory PickingLine.fromJson(Map<String, dynamic> j) => PickingLine(
        index: asInt(j['index']),
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        batchCode: asStr(j['batchCode']),
        need: asInt(j['need']),
        expiry: asDate(j['expiry']),
        location: asStr(j['location']),
        picked: asInt(j['picked']),
        suggestedLabel: asStr(j['suggestedLabel']),
        outLabel: asStr(j['outLabel']),
      );

  final int index;
  final String sku;
  final String name;
  final String batchCode;
  final int need;
  final DateTime? expiry;
  final String location;
  final int picked;

  /// FEFO-suggested source label (TEM).
  final String suggestedLabel;

  /// New child label that leaves with the order, set after picking.
  final String outLabel;

  bool get isDone => picked >= need;

  PickingLine copyWith({int? picked, String? outLabel}) => PickingLine(
        index: index,
        sku: sku,
        name: name,
        batchCode: batchCode,
        need: need,
        expiry: expiry,
        location: location,
        picked: picked ?? this.picked,
        suggestedLabel: suggestedLabel,
        outLabel: outLabel ?? this.outLabel,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'sku': sku,
        'name': name,
        'batchCode': batchCode,
        'need': need,
        'expiry': isoOrNull(expiry),
        'location': location,
        'picked': picked,
        'suggestedLabel': suggestedLabel,
        'outLabel': outLabel,
      };
}

/// Picking list `{order}{A/B/C}` - one per warehouse.
class PickingList {
  const PickingList({
    required this.code,
    required this.orderCode,
    required this.retailerCode,
    required this.retailerName,
    required this.status,
    required this.lines,
    this.warehouseName = '',
    this.approvedAt,
    this.shippedAt,
    this.siblingText = '',
  });

  factory PickingList.fromJson(Map<String, dynamic> j) => PickingList(
        code: asStr(j['code']),
        orderCode: asStr(j['orderCode']),
        retailerCode: asStr(j['retailerCode']),
        retailerName: asStr(j['retailerName']),
        status: PickingStatus.fromCode(asStrOrNull(j['status'])),
        lines: mapList(j['lines'], PickingLine.fromJson),
        warehouseName: asStr(j['warehouseName']),
        approvedAt: asDate(j['approvedAt']),
        shippedAt: asDate(j['shippedAt']),
        siblingText: asStr(j['siblingText']),
      );

  final String code;
  final String orderCode;
  final String retailerCode;
  final String retailerName;
  final PickingStatus status;
  final List<PickingLine> lines;
  final String warehouseName;
  final DateTime? approvedAt;
  final DateTime? shippedAt;
  final String siblingText;

  int get totalNeed => lines.fold<int>(0, (s, l) => s + l.need);
  int get totalPicked => lines.fold<int>(0, (s, l) => s + l.picked);
  int get doneLines => lines.where((l) => l.isDone).length;
  bool get allDone => lines.isNotEmpty && doneLines == lines.length;
  bool get isShipped => status == PickingStatus.shipped;

  PickingList copyWith({
    PickingStatus? status,
    List<PickingLine>? lines,
    DateTime? shippedAt,
  }) =>
      PickingList(
        code: code,
        orderCode: orderCode,
        retailerCode: retailerCode,
        retailerName: retailerName,
        status: status ?? this.status,
        lines: lines ?? this.lines,
        warehouseName: warehouseName,
        approvedAt: approvedAt,
        shippedAt: shippedAt ?? this.shippedAt,
        siblingText: siblingText,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'orderCode': orderCode,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'status': status.code,
        'lines': lines.map((l) => l.toJson()).toList(),
        'warehouseName': warehouseName,
        'approvedAt': isoOrNull(approvedAt),
        'shippedAt': isoOrNull(shippedAt),
        'siblingText': siblingText,
      };
}

/// Response of `POST /picking-lists/{code}/scan`.
class PickScanResult {
  const PickScanResult({
    required this.list,
    required this.childLabel,
    required this.remainingLabel,
    required this.remainingQty,
    required this.pickedQty,
  });

  factory PickScanResult.fromJson(Map<String, dynamic> j) => PickScanResult(
        list: PickingList.fromJson(asMap(j['list'])),
        childLabel: asStr(j['childLabel']),
        remainingLabel: asStr(j['remainingLabel']),
        remainingQty: asInt(j['remainingQty']),
        pickedQty: asInt(j['pickedQty']),
      );

  final PickingList list;

  /// New child TEM that travels with the order ("tem con").
  final String childLabel;

  /// Parent label that stays on the shelf and its remaining quantity.
  final String remainingLabel;
  final int remainingQty;
  final int pickedQty;
}
