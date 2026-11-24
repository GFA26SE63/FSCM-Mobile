import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';

/// Retailer overview at the top of "Đơn hàng": what needs the store's action
/// (quotes, payments, deliveries to scan, debt) plus the loyalty balance.
class RetailerTodoCard extends ConsumerWidget {
  const RetailerTodoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todo = ref.watch(retailerTodoProvider).valueOrNull;
    if (todo == null) return const SizedBox.shrink();

    final items = <_TodoItem>[
      if (todo.quotesToConfirm > 0)
        _TodoItem(
            Icons.request_quote_outlined,
            '${todo.quotesToConfirm} báo giá chờ bạn xác nhận',
            AppColors.primary),
      if (todo.paymentsPending > 0)
        _TodoItem(
            Icons.payments_outlined,
            '${todo.paymentsPending} đơn chờ thanh toán trước',
            AppColors.warning),
      if (todo.deliveriesToReceive > 0)
        _TodoItem(
            Icons.qr_code_scanner,
            '${todo.deliveriesToReceive} đơn đang giao · quét QR khi nhận hàng',
            AppColors.primary),
      if (todo.overdueCount > 0)
        _TodoItem(
            Icons.warning_amber_rounded,
            '${todo.overdueCount} khoản quá hạn · ${Money.format(todo.overdueAmount)}',
            AppColors.danger,
            route: AppRoutes.rtPayments),
      if (todo.dueSoonCount > 0)
        _TodoItem(
            Icons.event_outlined,
            '${todo.dueSoonCount} khoản đến hạn trong 7 ngày · ${Money.format(todo.dueSoonAmount)}',
            AppColors.warning,
            route: AppRoutes.rtPayments),
    ];

    return AppCard(
      key: const Key('retailer_todo'),
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.card, AppSpacing.card, AppSpacing.card, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Text(
                todo.hasAction ? 'Việc cần làm' : 'Không có việc cần xử lý',
                style: AppText.sectionTitle,
              ),
              if (todo.loyaltyPoints != null)
                // Loyalty balance as a gold pill (prototype loyalty card).
                InkWell(
                  borderRadius: AppRadius.pillAll,
                  onTap: () => context.push(AppRoutes.rtLoyalty),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s10, vertical: AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.stars_outlined,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text('Tích điểm · ${todo.loyaltyPoints} điểm',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption
                                  .copyWith(color: AppColors.warning)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            InkWell(
              borderRadius: AppRadius.controlAll,
              onTap:
                  item.route == null ? null : () => context.push(item.route!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smallAll,
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(child: Text(item.text, style: AppText.bodyMedium)),
                    if (item.route != null)
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodoItem {
  const _TodoItem(this.icon, this.text, this.color, {this.route});
  final IconData icon;
  final String text;
  final Color color;
  final String? route;
}
