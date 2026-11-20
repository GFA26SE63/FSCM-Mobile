import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

enum _DebtFilter { all, overdue, unpaid, paid }

/// "Công nợ cần thu": my retailers' credit orders with an overdue filter.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  _DebtFilter _filter = _DebtFilter.all;

  bool _match(Receivable r) {
    switch (_filter) {
      case _DebtFilter.all:
        return true;
      case _DebtFilter.overdue:
        return r.isOverdue;
      case _DebtFilter.unpaid:
        return !r.isPaid && !r.isOverdue;
      case _DebtFilter.paid:
        return r.isPaid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(receivablesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Công nợ cần thu')),
      body: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          ChipFilterBar<_DebtFilter>(
            options: const <ChipOption<_DebtFilter>>[
              ChipOption<_DebtFilter>(_DebtFilter.all, 'Tất cả'),
              ChipOption<_DebtFilter>(_DebtFilter.overdue, 'Quá hạn'),
              ChipOption<_DebtFilter>(_DebtFilter.unpaid, 'Chưa đến hạn'),
              ChipOption<_DebtFilter>(_DebtFilter.paid, 'Đã thu'),
            ],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          Expanded(
            child: AsyncBody<List<Receivable>>(
              value: value,
              onRetry: () => ref.invalidate(receivablesProvider),
              builder: (all) {
                final open = all
                    .where((r) => !r.isPaid)
                    .fold<int>(0, (s, r) => s + r.outstandingAmount);
                final list = all.where(_match).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(receivablesProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: <Widget>[
                      AppCard(
                        child: Row(
                          children: <Widget>[
                            const Expanded(
                                child: Text('Tổng còn phải thu',
                                    style: AppText.muted)),
                            Text(Money.format(open),
                                style: AppText.display
                                    .copyWith(color: AppColors.text)),
                          ],
                        ),
                      ),
                      const InfoBanner(
                        text:
                            'Hạn trả = ngày giao + kỳ hạn của điểm bán (7 / 14 / 30 ngày). Không quản lý hạn mức; khoản quá hạn được nhắc để bạn đi truy thu. Chuyển khoản do nhân viên vận hành xác nhận trên Portal.',
                      ),
                      if (list.isEmpty) const SizedBox(height: 40),
                      if (list.isEmpty)
                        const EmptyState(
                            title: 'Không có khoản công nợ phù hợp.'),
                      for (final r in list) _tile(context, r),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Receivable r) {
    final daysLate = r.daysOverdue(AppClock.now());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(r.retailerName, style: AppText.strong)),
              StatusChip(label: r.status.label, tone: r.status.tone),
            ],
          ),
          Text(
              '${r.orderCode} · giao ${AppDates.dayMonth(r.deliveredAt)} · hạn ${AppDates.date(r.dueDate)}',
              style: AppText.muted),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Text(Money.format(r.isPaid ? r.amount : r.outstandingAmount),
                  style: AppText.strong.copyWith(fontSize: 17)),
              const SizedBox(width: AppSpacing.s10),
              if (r.isOverdue)
                Text('Quá hạn $daysLate ngày',
                    style: AppText.cardTitle.copyWith(color: AppColors.danger)),
            ],
          ),
          if (!r.isPaid) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _collect(context, r),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Ghi nhận đã thu tiền mặt'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _collect(BuildContext context, Receivable r) async {
    final ok = await confirmDialog(
      context,
      title: 'Ghi nhận đã thu?',
      message:
          'Xác nhận đã thu đủ ${Money.format(r.outstandingAmount)} tiền mặt của ${r.retailerName} cho đơn ${r.orderCode}. Không thu từng phần.',
      confirmLabel: 'Đã thu đủ',
    );
    if (!ok) return;
    try {
      await ref.read(financeRepositoryProvider).collect(r);
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        showAppSnack(this.context,
            'Đã ghi nhận thu ${Money.format(r.outstandingAmount)} cho ${r.orderCode}.');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(this.context, e.message, error: true);
    }
  }
}
