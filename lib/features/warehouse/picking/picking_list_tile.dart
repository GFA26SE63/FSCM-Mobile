import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/quantity.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Row of one run picking sheet.
///
/// There is no single retailer to name here: a sheet is one warehouse's share
/// of a whole run, so it is summarised by how many batches it gathers and how
/// many orders those gathers split back to.
class PickingListTile extends StatelessWidget {
  const PickingListTile({super.key, required this.sheet});

  final RunPickingSheet sheet;

  @override
  Widget build(BuildContext context) {
    final s = sheet;
    final orders = s.orderCodes.length;
    return AppCard(
      onTap: () => context.push(AppRoutes.wkPickingDetail(s.pickingCode)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text(s.pickingCode,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
              StatusChip(label: s.status.label, tone: s.status.tone),
            ],
          ),
          Text('${s.gathers.length} lượt lấy · $orders đơn',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            'Đã lấy ${Qty.format(s.totalPicked)}/${Qty.cartons(s.totalRequired)} · '
            'phát hành ${AppDates.timeDay(s.issuedAt)}',
          ),
          if (s.hasException)
            Text('Ngoại lệ: ${s.exceptionType}',
                style: const TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
