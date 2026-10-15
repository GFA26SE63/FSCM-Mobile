import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';

/// Label (tem QR) `TEM-000000`. The QR only encodes the code; quantity and
/// status live on the server (`GET /labels/{code}`).
class LabelInfo {
  const LabelInfo({
    required this.code,
    required this.sku,
    required this.name,
    required this.batchCode,
    required this.qty,
    required this.status,
    this.expiry,
    this.location = '',
    this.warehouseName = '',
    this.parentCode = '',
    this.pickingCode = '',
    this.orderCode = '',
    this.children = const <String>[],
    this.history = const <TimelineEntry>[],
  });

  factory LabelInfo.fromJson(Map<String, dynamic> j) => LabelInfo(
        code: asStr(j['code']),
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        batchCode: asStr(j['batchCode']),
        qty: asInt(j['qty']),
        status: LabelStatus.fromCode(asStrOrNull(j['status'])),
        expiry: asDate(j['expiry']),
        location: asStr(j['location']),
        warehouseName: asStr(j['warehouseName']),
        parentCode: asStr(j['parentCode']),
        pickingCode: asStr(j['pickingCode']),
        orderCode: asStr(j['orderCode']),
        children: asStrList(j['children']),
        history: mapList(j['history'], TimelineEntry.fromJson),
      );

  final String code;
  final String sku;
  final String name;
  final String batchCode;
  final int qty;
  final LabelStatus status;
  final DateTime? expiry;
  final String location;
  final String warehouseName;
  final String parentCode;
  final String pickingCode;
  final String orderCode;
  final List<String> children;
  final List<TimelineEntry> history;

  LabelInfo copyWith({
    int? qty,
    LabelStatus? status,
    String? location,
    String? warehouseName,
    String? pickingCode,
    List<String>? children,
    List<TimelineEntry>? history,
  }) =>
      LabelInfo(
        code: code,
        sku: sku,
        name: name,
        batchCode: batchCode,
        qty: qty ?? this.qty,
        status: status ?? this.status,
        expiry: expiry,
        location: location ?? this.location,
        warehouseName: warehouseName ?? this.warehouseName,
        parentCode: parentCode,
        pickingCode: pickingCode ?? this.pickingCode,
        orderCode: orderCode,
        children: children ?? this.children,
        history: history ?? this.history,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'sku': sku,
        'name': name,
        'batchCode': batchCode,
        'qty': qty,
        'status': status.code,
        'expiry': isoOrNull(expiry),
        'location': location,
        'warehouseName': warehouseName,
        'parentCode': parentCode,
        'pickingCode': pickingCode,
        'orderCode': orderCode,
        'children': children,
        'history': history.map((h) => h.toJson()).toList(),
      };
}
