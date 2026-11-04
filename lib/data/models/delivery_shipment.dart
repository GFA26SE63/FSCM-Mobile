import 'package:fscm_mobile/data/models/json_utils.dart';

class DeliveryShipmentLine {
  const DeliveryShipmentLine({
    required this.orderLineId,
    required this.batchId,
    required this.sku,
    required this.batchCode,
    required this.quantity,
  });

  factory DeliveryShipmentLine.fromJson(Map<String, dynamic> json) =>
      DeliveryShipmentLine(
        orderLineId: asStr(json['orderLineId']),
        batchId: asStr(json['batchId']),
        sku: asStr(json['sku']),
        batchCode: asStr(json['batchCode']),
        quantity: asDouble(json['quantity']),
      );

  final String orderLineId;
  final String batchId;
  final String sku;
  final String batchCode;
  final double quantity;
}

class DeliveryShipment {
  const DeliveryShipment({
    required this.id,
    required this.code,
    required this.warehouseCode,
    required this.warehouseName,
    required this.status,
    required this.totalQuantity,
    required this.receivedQuantity,
    required this.version,
    required this.lines,
  });

  factory DeliveryShipment.fromJson(Map<String, dynamic> json) =>
      DeliveryShipment(
        id: asStr(json['id']),
        code: asStr(json['shipmentCode']),
        warehouseCode: asStr(json['warehouseCode']),
        warehouseName: asStr(json['warehouseName']),
        status: asStr(json['status']),
        totalQuantity: asDouble(json['totalQuantity']),
        receivedQuantity: asDouble(json['receivedQuantity']),
        version: asInt(json['version']),
        lines: asMapList(json['lines'])
            .map(DeliveryShipmentLine.fromJson)
            .toList(growable: false),
      );

  final String id;
  final String code;
  final String warehouseCode;
  final String warehouseName;
  final String status;
  final double totalQuantity;
  final double receivedQuantity;
  final int version;
  final List<DeliveryShipmentLine> lines;

  bool get canReceive => status == 'Delivering';
}
