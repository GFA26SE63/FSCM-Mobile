import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
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
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                  entry.kind == PointKind.unknown
                      ? 'Giao dịch khác · ${entry.transactionType}'
                      : entry.kind.label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('$signed điểm',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ]),
        Text(AppDates.timeDay(entry.date),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        Text(entry.description),
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
          Text('Yêu cầu đổi quà: ${entry.redemptionId}'),
          if (entry.redemptionStatus != null)
            Text('Trạng thái: ${_redemptionStatus(entry.redemptionStatus!)}'),
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
        'Delivered' => 'Đã giao',
        'Completed' => 'Hoàn tất',
        'Rejected' => 'Từ chối',
        'Cancelled' => 'Đã hủy',
        _ => value,
      };
}
