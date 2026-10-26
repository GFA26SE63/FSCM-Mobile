import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// One line of a warehouse's part of an order, priced as the run approved it.
///
/// [unitPrice] and [netAmount] are the locked per-batch amounts, read and never
/// recomputed: the moment a discount table changes, a figure worked out on the
/// phone would stop matching the invoice and nobody would notice until a
/// reconciliation.
class ShipmentLine {
  const ShipmentLine({
    required this.orderLineId,
    required this.lineNumber,
    required this.sku,
    required this.productName,
    required this.batchCode,
    required this.quantity,
    required this.unitPrice,
    required this.netAmount,
  });

  factory ShipmentLine.fromJson(Map<String, dynamic> j) => ShipmentLine(
        orderLineId: asStr(j['orderLineId']),
        lineNumber: asInt(j['lineNumber']),
        sku: asStr(j['sku']),
        productName: asStr(j['productName']),
        batchCode: asStr(j['batchCode']),
        quantity: asDouble(j['quantity']),
        unitPrice: asDouble(j['unitPrice']),
        netAmount: asDouble(j['netAmount']),
      );

  final String orderLineId;
  final int lineNumber;
  final String sku;
  final String productName;
  final String batchCode;
  final double quantity;
  final double unitPrice;
  final double netAmount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderLineId': orderLineId,
        'lineNumber': lineNumber,
        'sku': sku,
        'productName': productName,
        'batchCode': batchCode,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'netAmount': netAmount,
      };
}

/// One warehouse's part of one order, as `GET /shipments` returns it.
///
/// [version] is what the issue confirmation must send back, so a part cannot be
/// confirmed against a state someone else has already moved on from.
class Shipment {
  const Shipment({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.warehouseId,
    required this.warehouseCode,
    required this.warehouseName,
    required this.pickingCode,
    required this.shipmentCode,
    required this.status,
    required this.totalQuantity,
    required this.version,
    this.issuedAt,
    this.exceptionReason,
    this.lines = const <ShipmentLine>[],
  });

  factory Shipment.fromJson(Map<String, dynamic> j) => Shipment(
        id: asStr(j['id']),
        orderId: asStr(j['orderId']),
        orderCode: asStr(j['orderCode']),
        warehouseId: asStr(j['warehouseId']),
        warehouseCode: asStr(j['warehouseCode']),
        warehouseName: asStr(j['warehouseName']),
        pickingCode: asStr(j['pickingCode']),
        shipmentCode: asStr(j['shipmentCode']),
        status: ShipmentPartStatus.fromCode(asStrOrNull(j['status'])),
        totalQuantity: asDouble(j['totalQuantity']),
        version: asInt(j['version']),
        issuedAt: asDate(j['issuedAt']),
        exceptionReason: asStrOrNull(j['exceptionReason']),
        lines: mapList(j['lines'], ShipmentLine.fromJson),
      );

  final String id;
  final String orderId;
  final String orderCode;
  final String warehouseId;
  final String warehouseCode;
  final String warehouseName;
  final String pickingCode;
  final String shipmentCode;
  final ShipmentPartStatus status;
  final double totalQuantity;
  final int version;
  final DateTime? issuedAt;
  final String? exceptionReason;
  final List<ShipmentLine> lines;

  bool get hasLeft => status.hasLeft;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'orderId': orderId,
        'orderCode': orderCode,
        'warehouseId': warehouseId,
        'warehouseCode': warehouseCode,
        'warehouseName': warehouseName,
        'pickingCode': pickingCode,
        'shipmentCode': shipmentCode,
        'status': status.code,
        'totalQuantity': totalQuantity,
        'version': version,
        'issuedAt': isoOrNull(issuedAt),
        'exceptionReason': exceptionReason,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}

/// One warehouse's part as the readiness check reports it.
class ShipmentReadinessPart {
  const ShipmentReadinessPart({
    required this.shipmentId,
    required this.shipmentCode,
    required this.warehouseId,
    required this.warehouseCode,
    required this.status,
    this.exceptionReason,
  });

  factory ShipmentReadinessPart.fromJson(Map<String, dynamic> j) =>
      ShipmentReadinessPart(
        shipmentId: asStr(j['shipmentId']),
        shipmentCode: asStr(j['shipmentCode']),
        warehouseId: asStr(j['warehouseId']),
        warehouseCode: asStr(j['warehouseCode']),
        status: ShipmentPartStatus.fromCode(asStrOrNull(j['status'])),
        exceptionReason: asStrOrNull(j['exceptionReason']),
      );

  final String shipmentId;
  final String shipmentCode;
  final String warehouseId;
  final String warehouseCode;
  final ShipmentPartStatus status;
  final String? exceptionReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'shipmentId': shipmentId,
        'shipmentCode': shipmentCode,
        'warehouseId': warehouseId,
        'warehouseCode': warehouseCode,
        'status': status.code,
        'exceptionReason': exceptionReason,
      };
}

/// F93: whether a whole order may leave its warehouses.
///
/// The decision belongs to the server and is taken for the order, never for one
/// warehouse: an order is all or nothing at the door, so one warehouse short or
/// damaged holds every other part too. [isReady] is the only thing a confirm
/// button may be enabled on - [parts] and [blockingReasons] exist to explain it,
/// not to be recombined into a verdict of the app's own.
class OrderShipmentReadiness {
  const OrderShipmentReadiness({
    required this.salesOrderId,
    required this.orderCode,
    required this.isReady,
    required this.paymentSettled,
    required this.hasException,
    required this.blockingReasons,
    required this.parts,
  });

  factory OrderShipmentReadiness.fromJson(Map<String, dynamic> j) =>
      OrderShipmentReadiness(
        salesOrderId: asStr(j['salesOrderId']),
        orderCode: asStr(j['orderCode']),
        isReady: asBool(j['isReady']),
        paymentSettled: asBool(j['paymentSettled']),
        hasException: asBool(j['hasException']),
        blockingReasons: asStrList(j['blockingReasons']),
        parts: mapList(j['parts'], ShipmentReadinessPart.fromJson),
      );

  final String salesOrderId;
  final String orderCode;
  final bool isReady;
  final bool paymentSettled;
  final bool hasException;
  final List<String> blockingReasons;
  final List<ShipmentReadinessPart> parts;

  ShipmentReadinessPart? partOf(String warehouseId) {
    for (final part in parts) {
      if (part.warehouseId == warehouseId) return part;
    }
    return null;
  }

  List<ShipmentReadinessPart> othersThan(String warehouseId) =>
      parts.where((p) => p.warehouseId != warehouseId).toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'salesOrderId': salesOrderId,
        'orderCode': orderCode,
        'isReady': isReady,
        'paymentSettled': paymentSettled,
        'hasException': hasException,
        'blockingReasons': blockingReasons,
        'parts': parts.map((p) => p.toJson()).toList(),
      };
}
