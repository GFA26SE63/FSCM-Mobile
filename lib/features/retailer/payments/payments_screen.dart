import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// "Thanh toán & công nợ": amount paid so far and the credit due list.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivables = ref.watch(receivablesProvider);
    final orders =
        ref.watch(ordersProvider).valueOrNull?.orders ?? const <Order>[];
    final paidTotal =
        orders.where((o) => o.paid).fold<int>(0, (s, o) => s + o.finalAmount);
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán & công nợ')),
      body: AsyncBody<List<Receivable>>(
        value: receivables,
        onRetry: () => ref.invalidate(receivablesProvider),
        builder: (all) {
          final open = all.where((r) => !r.isPaid).toList()
            ..sort((a, b) => (a.dueDate ?? DateTime(2100))
                .compareTo(b.dueDate ?? DateTime(2100)));
          final paid = all.where((r) => r.isPaid).toList();
          final openTotal = open.fold<int>(0, (s, r) => s + r.amount);
          final overdue = open.where((r) => r.isOverdue).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                      child: _Summary(
                          label: 'Đã thanh toán',
                          value: Money.format(paidTotal),
                          color: AppColors.success)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Summary(
                          label: 'Còn nợ',
                          value: Money.format(openTotal),
                          color: overdue.isEmpty
                              ? AppColors.text
                              : AppColors.danger)),
                ],
              ),
              if (overdue.isNotEmpty)
                InfoBanner(
                  tone: StatusTone.danger,
                  icon: Icons.warning_amber_rounded,
                  title: '${overdue.length} khoản quá hạn',
                  text:
                      'Vui lòng thanh toán cho nhân viên bán hàng để tiếp tục đặt hàng công nợ và nhận điểm tích lũy.',
                ),
              const SectionTitle('Công nợ cần thanh toán'),
              if (open.isEmpty)
                const SizedBox(
                    height: 120,
                    child: EmptyState(
                        title: 'Không có công nợ.',
                        icon: Icons.verified_outlined))
              else
                for (final r in open) _ReceivableTile(receivable: r),
              if (paid.isNotEmpty) ...<Widget>[
                const SectionTitle('Đã thanh toán'),
                for (final r in paid) _ReceivableTile(receivable: r),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _ReceivableTile extends StatelessWidget {
  const _ReceivableTile({required this.receivable});

  final Receivable receivable;

  @override
  Widget build(BuildContext context) {
    final r = receivable;
    final days = r.daysOverdue(AppClock.now());
    final String dueText;
    if (r.isPaid) {
      dueText = 'Thanh toán ${AppDates.date(r.paidAt)}';
    } else if (days > 0) {
      dueText = 'Hạn ${AppDates.date(r.dueDate)} · quá hạn $days ngày';
    } else {
      dueText = 'Hạn ${AppDates.date(r.dueDate)} · còn ${-days} ngày';
    }
    return AppCard(
      onTap: () => context.push(AppRoutes.rtOrderDetail(r.orderCode)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(r.orderCode,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(dueText,
                    style: TextStyle(
                        color: r.isOverdue
                            ? AppColors.danger
                            : AppColors.textMuted,
                        fontSize: 13)),
                Text('Công nợ ${r.term} ngày',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(Money.format(r.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              StatusChip(label: r.status.label, tone: r.status.tone),
            ],
          ),
        ],
      ),
    );
  }
}
