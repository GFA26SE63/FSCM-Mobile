import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Row of a picking list (code, retailer, status, lines/cartons).
class PickingListTile extends StatelessWidget {
  const PickingListTile({super.key, required this.list});

  final PickingList list;

  @override
  Widget build(BuildContext context) {
    final p = list;
    return AppCard(
      onTap: () => context.push(AppRoutes.wkPickingDetail(p.code)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text(p.code,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
              StatusChip(label: p.status.label, tone: p.status.tone),
            ],
          ),
          Text('${p.retailerName} · ${p.retailerCode}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            '${p.lines.length} dòng · ${p.totalNeed} thùng · '
            '${p.status == PickingStatus.shipped ? 'xuất ${AppDates.timeDay(p.shippedAt)}' : 'duyệt ${AppDates.timeDay(p.approvedAt)}'}',
          ),
        ],
      ),
    );
  }
}
