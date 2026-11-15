import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

class WarehouseStockList extends StatelessWidget {
  const WarehouseStockList(
      {super.key, required this.warehouses, this.maxItems = 3, this.onViewAll});
  final List<WarehouseAvailability> warehouses;
  final int? maxItems;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) {
    final visible =
        ProductAvailability(sku: '', quantity: 0, warehouses: warehouses)
            .serviceWarehouses;
    final preview = maxItems == null ? visible : visible.take(maxItems!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tồn đủ điều kiện theo kho',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        if (warehouses.isEmpty)
          const Text('Chưa có dữ liệu chi tiết theo kho.')
        else if (visible.every((w) => w.quantity <= 0))
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Không có hàng đủ điều kiện để giao.')),
        for (final warehouse in preview)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${warehouse.name} · ${warehouse.code}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (warehouse.quantity == 0)
                      Text(warehouse.reasonLabel,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    if (warehouse.distanceMeters != null)
                      Text(
                          '${(warehouse.distanceMeters! / 1000).toStringAsFixed(1).replaceAll('.', ',')} km',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                  ])),
              const SizedBox(width: 8),
              Text('${warehouse.quantity} thùng',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: warehouse.quantity > 0
                          ? AppColors.primary
                          : AppColors.textMuted)),
            ]),
          ),
        if (maxItems != null && visible.length > maxItems!)
          TextButton(
              onPressed: onViewAll,
              child: Text('Xem tất cả ${visible.length} kho')),
      ],
    );
  }
}
