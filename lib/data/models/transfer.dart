import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

class TransferLine {
  const TransferLine({
    required this.sku,
    required this.name,
    required this.batchCode,
    required this.qty,
    required this.labelCode,
    this.expiry,
    this.received = false,
  });

  factory TransferLine.fromJson(Map<String, dynamic> j) => TransferLine(
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        batchCode: asStr(j['batchCode']),
        qty: asInt(j['qty']),
        labelCode: asStr(j['labelCode']),
        expiry: asDate(j['expiry']),
        received: asBool(j['received']),
      );

  final String sku;
  final String name;
  final String batchCode;
  final int qty;

  /// Label travelling with the goods; scanned on receipt.
  final String labelCode;
  final DateTime? expiry;
  final bool received;

  TransferLine copyWith({bool? received}) => TransferLine(
        sku: sku,
        name: name,
        batchCode: batchCode,
        qty: qty,
        labelCode: labelCode,
        expiry: expiry,
        received: received ?? this.received,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sku': sku,
        'name': name,
        'batchCode': batchCode,
        'qty': qty,
        'labelCode': labelCode,
        'expiry': isoOrNull(expiry),
        'received': received,
      };
}

/// Warehouse transfer `DC-yyMMdd-nn` (replenishment or near-expiry rotation).
class Transfer {
  const Transfer({
    required this.code,
    required this.kind,
    required this.status,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.lines,
    this.shippedAt,
    this.expectedAt,
    this.receivedAt,
    this.distanceKm = 0,
    this.note = '',
  });

  factory Transfer.fromJson(Map<String, dynamic> j) => Transfer(
        code: asStr(j['code']),
        kind: TransferKind.fromCode(asStrOrNull(j['kind'])),
        status: TransferStatus.fromCode(asStrOrNull(j['status'])),
        fromWarehouse: asStr(j['fromWarehouse']),
        toWarehouse: asStr(j['toWarehouse']),
        lines: mapList(j['lines'], TransferLine.fromJson),
        shippedAt: asDate(j['shippedAt']),
        expectedAt: asDate(j['expectedAt']),
        receivedAt: asDate(j['receivedAt']),
        distanceKm: asDouble(j['distanceKm']),
        note: asStr(j['note']),
      );

  final String code;
  final TransferKind kind;
  final TransferStatus status;
  final String fromWarehouse;
  final String toWarehouse;
  final List<TransferLine> lines;
  final DateTime? shippedAt;
  final DateTime? expectedAt;
  final DateTime? receivedAt;
  final double distanceKm;
  final String note;

  int get totalQty => lines.fold<int>(0, (s, l) => s + l.qty);
  bool get isNearExpiry => kind == TransferKind.nearExpiryRotation;

  Transfer copyWith(
          {TransferStatus? status,
          DateTime? receivedAt,
          List<TransferLine>? lines}) =>
      Transfer(
        code: code,
        kind: kind,
        status: status ?? this.status,
        fromWarehouse: fromWarehouse,
        toWarehouse: toWarehouse,
        lines: lines ?? this.lines,
        shippedAt: shippedAt,
        expectedAt: expectedAt,
        receivedAt: receivedAt ?? this.receivedAt,
        distanceKm: distanceKm,
        note: note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'kind': kind.code,
        'status': status.code,
        'fromWarehouse': fromWarehouse,
        'toWarehouse': toWarehouse,
        'lines': lines.map((l) => l.toJson()).toList(),
        'shippedAt': isoOrNull(shippedAt),
        'expectedAt': isoOrNull(expectedAt),
        'receivedAt': isoOrNull(receivedAt),
        'distanceKm': distanceKm,
        'note': note,
      };
}
