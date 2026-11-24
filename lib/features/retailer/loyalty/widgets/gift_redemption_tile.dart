import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

class GiftRedemptionTile extends StatelessWidget {
  const GiftRedemptionTile(
      {super.key, required this.request, this.highlight = false});
  final GiftRedemption request;
  final bool highlight;

  @override
  Widget build(BuildContext context) => AppCard(
      color: highlight ? AppColors.primarySoft : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(request.giftName, style: AppText.strong),
              StatusChip(
                  label: request.status.label, tone: request.status.tone),
            ]),
        const SizedBox(height: AppSpacing.s6),
        Text(request.code, style: AppText.mutedSmall),
        Text(AppDates.timeDay(request.requestedAt)),
        Text(request.quantity == null
            ? 'Chưa có dữ liệu số lượng'
            : '${request.quantity} quà${request.quantityIsEstimated ? ' (ước tính từ dữ liệu cũ)' : ''}'),
        Text('Tổng ${request.points} điểm'),
      ]));
}
