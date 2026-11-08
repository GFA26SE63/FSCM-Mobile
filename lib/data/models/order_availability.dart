import 'package:fscm_mobile/data/models/json_utils.dart';

class WarehouseAvailability {
  const WarehouseAvailability(
      {required this.id,
      required this.code,
      required this.name,
      required this.quantity,
      this.distanceMeters,
      this.unavailableReason});
  factory WarehouseAvailability.fromJson(Map<String, dynamic> json) =>
      WarehouseAvailability(
        id: asStr(json['warehouseId']),
        code: asStr(json['warehouseCode']),
        name: asStr(json['warehouseName']),
        quantity: asInt(json['eligibleQuantity']),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        unavailableReason: asStrOrNull(json['unavailableReason']),
      );
  final String id;
  final String code;
  final String name;
  final int quantity;
  final double? distanceMeters;
  final String? unavailableReason;
  String get reasonLabel => switch (unavailableReason) {
        'OutsideServiceRadius' => 'Ngoài phạm vi phục vụ',
        'RouteUnavailable' => 'Chưa xác định được tuyến giao',
        'BelowMlor' => 'Hạn dùng khi giao không đạt yêu cầu',
        'MissingMlor' => 'Chưa có điều kiện hạn dùng',
        'NoIssuableStock' => 'Không còn tồn có thể cấp',
        _ => 'Không có batch đủ điều kiện giao',
      };
}

class ProductAvailability {
  const ProductAvailability(
      {required this.sku, required this.quantity, required this.warehouses});
  factory ProductAvailability.fromJson(Map<String, dynamic> json) =>
      ProductAvailability(
        sku: asStr(json['sku']),
        quantity: asInt(json['eligibleQuantity']),
        warehouses: asMapList(json['warehouses'])
            .map(WarehouseAvailability.fromJson)
            .toList(),
      );
  final String sku;
  final int quantity;
  final List<WarehouseAvailability> warehouses;
}
