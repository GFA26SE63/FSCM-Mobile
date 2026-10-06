import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_presenters.dart';

class WarehousePickingCard extends StatelessWidget {
  const WarehousePickingCard({
    super.key,
    required this.picking,
    required this.onTap,
  });

  final PickingList picking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FscmCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  picking.id,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: pickingStatusLabel(picking.status),
                color: pickingStatusColor(picking.status),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            picking.retailerName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            '${picking.lines.length} dòng · ${picking.totalQuantity} thùng · duyệt ${picking.approvedAt}',
            style: const TextStyle(color: FscmColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
