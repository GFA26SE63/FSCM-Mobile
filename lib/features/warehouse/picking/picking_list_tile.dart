import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Row of a picking list matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.warehouse`).
class PickingListTile extends StatelessWidget {
  const PickingListTile({super.key, required this.list});

  final PickingList list;

  @override
  Widget build(BuildContext context) {
    final p = list;
    final highlightBorder = p.status != PickingStatus.shipped
        ? const Color(0xFFB9CBEF)
        : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push(AppRoutes.wkPickingDetail(p.code)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlightBorder,
              width: p.status != PickingStatus.shipped ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Phần giao ${p.code}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${p.retailerName} (${p.retailerCode}) · Duyệt ${AppDates.timeDay(p.approvedAt)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(label: p.status.label, tone: p.status.tone),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    '${p.lines.length} dòng · ${p.totalNeed} thùng',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'Đã lấy ${p.doneLines}/${p.lines.length} dòng',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
