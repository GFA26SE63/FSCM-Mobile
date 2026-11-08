import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

class WarehouseStockList extends StatelessWidget {
  const WarehouseStockList({super.key, required this.warehouses});
  final List<WarehouseAvailability> warehouses;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tồn đủ điều kiện theo kho',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (warehouses.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Chưa có tồn theo kho.')),
          for (final warehouse in warehouses)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ],
      );
}
