import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/shared/widgets/warehouse_stock_list.dart';

/// Availability is a point-in-time total, not a reservation or a warehouse list.
class OrderStockSummary extends StatelessWidget {
  const OrderStockSummary(
      {super.key,
      required this.availability,
      this.maxWarehouses = 3,
      this.onViewAll});
  final ProductAvailability availability;
  final int? maxWarehouses;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Đủ điều kiện giao cho điểm bán: ${availability.quantity} thùng'),
          if (availability.checkedAt != null)
            Text(
                'Kiểm tra lúc ${AppDates.timeDay(availability.checkedAt!.toLocal())}'),
          const Text('Chưa giữ hàng; số lượng có thể thay đổi khi phân bổ.'),
          if (availability.warehouses.isNotEmpty)
            WarehouseStockList(
                warehouses: availability.warehouses,
                maxItems: maxWarehouses,
                onViewAll: onViewAll),
        ],
      );
}
