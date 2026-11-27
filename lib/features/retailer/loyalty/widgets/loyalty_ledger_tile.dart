import 'package:fscm_mobile/core/utils/status_labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

class LoyaltyLedgerTile extends StatelessWidget {
  const LoyaltyLedgerTile({super.key, required this.entry});
  final PointLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final neutral = entry.kind == PointKind.pending ||
        entry.kind == PointKind.pendingCancelled ||
        entry.kind == PointKind.held ||
        entry.kind == PointKind.unknown;
    final color = neutral
        ? AppColors.textMuted
        : entry.points < 0
            ? AppColors.danger
            : AppColors.success;
    final signed = '${entry.points > 0 ? '+' : ''}${entry.points}';
    return AppCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
                neutral
                    ? Icons.hourglass_empty
                    : entry.points < 0
                        ? Icons.north_east
                        : Icons.south_west,
                size: 18,
                color: color),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  entry.kind == PointKind.unknown
                      ? 'Giao dịch khác · ${entry.transactionType}'
                      : entry.kind.label,
                  style: AppText.strong),
              Text(AppDates.timeDay(entry.date), style: AppText.mutedSmall),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text('$signed điểm',
                  style: AppText.strong.copyWith(color: color)),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(entry.description, style: AppText.bodyMedium),
        KvRow('Khả dụng sau giao dịch', '${entry.balanceAfter} điểm'),
        if (entry.orderId != null)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.rtOrderDetail(entry.orderId!)),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(entry.orderCode == null
                      ? 'Xem đơn nguồn'
                      : 'Xem đơn ${entry.orderCode}'))),
        if (entry.redemptionId != null) ...[
          if (entry.redemptionStatus != null)
            Text('Yêu cầu đổi quà: ${_redemptionStatus(entry.redemptionStatus!)}'),
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                  onPressed: () => context.push(Uri(
                          path: AppRoutes.rtGifts,
                          queryParameters: {
                            'redemptionId': entry.redemptionId!
                          }).toString()),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Xem yêu cầu đổi quà'))),
        ],
      ],
    ));
  }

  String _redemptionStatus(String value) => switch (value) {
        'Pending' => 'Chờ xử lý',
        'Approved' => 'Đã duyệt',
        'Delivered' => 'Đã giao quà',
        'Completed' => 'Hoàn tất',
        'Rejected' => 'Từ chối',
        'Cancelled' => 'Đã hủy',
        _ => unknownStatusLabel,
      };
}
