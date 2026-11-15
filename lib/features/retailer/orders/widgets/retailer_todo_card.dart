import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

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
        _TodoItem(Icons.request_quote_outlined,
            '${todo.quotesToConfirm} báo giá chờ bạn xác nhận', AppColors.primary),
      if (todo.paymentsPending > 0)
        _TodoItem(Icons.payments_outlined,
            '${todo.paymentsPending} đơn chờ thanh toán trước', AppColors.warning),
      if (todo.deliveriesToReceive > 0)
        _TodoItem(Icons.qr_code_scanner,
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

    return Container(
      key: const Key('retailer_todo'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  todo.hasAction ? 'Việc cần làm' : 'Không có việc cần xử lý',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (todo.loyaltyPoints != null)
                InkWell(
                  onTap: () => context.push(AppRoutes.rtLoyalty),
                  child: Text('${todo.loyaltyPoints} điểm',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in items)
            InkWell(
              onTap: item.route == null ? null : () => context.push(item.route!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Icon(item.icon, size: 18, color: item.color),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item.text,
                            style: const TextStyle(fontSize: 13.5))),
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
