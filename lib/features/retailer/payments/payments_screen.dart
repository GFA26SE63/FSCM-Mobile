import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/focus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/payos_checkout_result_page.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';

enum _PaymentFilter { all, payable, overdue, paid, prepaid }

enum _PaymentSort {
  dueSoonest,
  dueLatest,
  amountHighToLow,
  amountLowToHigh,
}

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final Set<String> _selected = <String>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _PaymentFilter _filter = _PaymentFilter.all;
  _PaymentSort _sort = _PaymentSort.dueSoonest;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Receivable receivable) {
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty &&
        !receivable.orderCode.toLowerCase().contains(query)) {
      return false;
    }

    switch (_filter) {
      case _PaymentFilter.all:
        return true;
      case _PaymentFilter.payable:
        return receivable.method == 'Credit' &&
            !receivable.isPaid &&
            !receivable.isCancelled &&
            receivable.collectibleAmount > 0;
      case _PaymentFilter.overdue:
        return receivable.isOverdue;
      case _PaymentFilter.paid:
        return receivable.isPaid;
      case _PaymentFilter.prepaid:
        return receivable.method == 'Prepaid' &&
            !receivable.isPaid &&
            !receivable.isCancelled &&
            receivable.outstandingAmount > 0;
    }
  }

  int _compare(Receivable a, Receivable b) {
    switch (_sort) {
      case _PaymentSort.dueSoonest:
        return (a.dueDate ?? DateTime(2100))
            .compareTo(b.dueDate ?? DateTime(2100));
      case _PaymentSort.dueLatest:
        return (b.dueDate ?? DateTime(1900))
            .compareTo(a.dueDate ?? DateTime(1900));
      case _PaymentSort.amountHighToLow:
        return _displayAmount(b).compareTo(_displayAmount(a));
      case _PaymentSort.amountLowToHigh:
        return _displayAmount(a).compareTo(_displayAmount(b));
    }
  }

  int _displayAmount(Receivable receivable) => receivable.isPaid
      ? receivable.confirmedAmount
      : receivable.method == 'Prepaid'
          ? receivable.outstandingAmount
          : receivable.collectibleAmount;

  @override
  Widget build(BuildContext context) {
    final receivables = ref.watch(receivablesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán & công nợ')),
      body: AsyncBody<List<Receivable>>(
        value: receivables,
        onRetry: () => ref.invalidate(receivablesProvider),
        builder: (all) {
          final payable = all
              .where((r) =>
                  r.method == 'Credit' &&
                  !r.isPaid &&
                  !r.isCancelled &&
                  r.collectibleAmount > 0)
              .toList();
          final visible = all.where(_matches).toList()..sort(_compare);
          final open = visible
              .where((r) =>
                  r.method == 'Credit' &&
                  !r.isPaid &&
                  !r.isCancelled &&
                  r.collectibleAmount > 0)
              .toList();
          final paid = visible.where((r) => r.isPaid).toList();
          final openTotal =
              payable.fold<int>(0, (sum, r) => sum + r.collectibleAmount);
          final selectedTotal = payable
              .where((r) => _selected.contains(r.paymentId))
              .fold<int>(0, (sum, r) => sum + r.collectibleAmount);
          final prepaid = visible
              .where((r) =>
                  r.method == 'Prepaid' &&
                  !r.isPaid &&
                  !r.isCancelled &&
                  r.outstandingAmount > 0)
              .toList();
          final overdue = payable.where((r) => r.isOverdue).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(receivablesProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
              children: <Widget>[
                Row(children: <Widget>[
                  Expanded(
                      child: _Summary(
                          label: 'Công nợ có thể trả',
                          value: Money.format(openTotal),
                          color: overdue.isEmpty
                              ? AppColors.text
                              : AppColors.danger)),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                      child: _Summary(
                          label: 'Các khoản đã chọn',
                          value: Money.format(selectedTotal),
                          color: AppColors.primary)),
                ]),
                if (overdue.isNotEmpty)
                  InfoBanner(
                    tone: StatusTone.danger,
                    icon: Icons.warning_amber_rounded,
                    title: '${overdue.length} khoản quá hạn',
                    text:
                        'Vui lòng thanh toán để tiếp tục đặt hàng công nợ và nhận điểm tích lũy.',
                  ),
                // Search, filters and sort grouped in one card (prototype toolbar).
                AppCard(
                  margin: const EdgeInsets.only(
                      top: AppSpacing.sm, bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            0, AppSpacing.md, 0, AppSpacing.sm),
                        child: TextField(
                          onTapOutside: releaseFocus,
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm mã đơn công nợ',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Xóa tìm kiếm',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() {
                                      _searchController.clear();
                                      _query = '';
                                    }),
                                  ),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      ChipFilterBar<_PaymentFilter>(
                        padding: EdgeInsets.zero,
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                        options: const <ChipOption<_PaymentFilter>>[
                          ChipOption(_PaymentFilter.all, 'Tất cả'),
                          ChipOption(_PaymentFilter.payable, 'Cần trả'),
                          ChipOption(_PaymentFilter.overdue, 'Quá hạn'),
                          ChipOption(_PaymentFilter.paid, 'Đã trả'),
                          ChipOption(_PaymentFilter.prepaid, 'Trả trước'),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: DropdownButtonFormField<_PaymentSort>(
                          value: _sort,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sắp xếp',
                            prefixIcon: Icon(Icons.sort),
                          ),
                          items: const <DropdownMenuItem<_PaymentSort>>[
                            DropdownMenuItem(
                              value: _PaymentSort.dueSoonest,
                              child: Text('Hạn thanh toán gần nhất'),
                            ),
                            DropdownMenuItem(
                              value: _PaymentSort.dueLatest,
                              child: Text('Hạn thanh toán xa nhất'),
                            ),
                            DropdownMenuItem(
                              value: _PaymentSort.amountHighToLow,
                              child: Text('Số tiền cao đến thấp'),
                            ),
                            DropdownMenuItem(
                              value: _PaymentSort.amountLowToHigh,
                              child: Text('Số tiền thấp đến cao'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sort = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (open.isNotEmpty || visible.isEmpty)
                  const SectionTitle('Công nợ cần thanh toán'),
                if (visible.isEmpty)
                  const SizedBox(
                      height: 140,
                      child: EmptyState(
                          title: 'Không có khoản công nợ phù hợp.',
                          icon: Icons.verified_outlined))
                else if (open.isNotEmpty)
                  for (final item in open)
                    _ReceivableTile(
                      receivable: item,
                      selected: _selected.contains(item.paymentId),
                      onSelected: (checked) => setState(() {
                        if (checked) {
                          _selected.add(item.paymentId);
                        } else {
                          _selected.remove(item.paymentId);
                        }
                      }),
                    ),
                if (paid.isNotEmpty) ...<Widget>[
                  const SectionTitle('Đã thanh toán'),
                  for (final item in paid) _ReceivableTile(receivable: item),
                ],
                if (prepaid.isNotEmpty) ...<Widget>[
                  const SectionTitle('Đơn trả trước đang chờ thanh toán'),
                  for (final item in prepaid) _ReceivableTile(receivable: item),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: receivables.valueOrNull == null
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                minimum: const EdgeInsets.all(AppSpacing.md),
                child: Row(children: <Widget>[
                  Expanded(
                      child: OutlinedButton(
                    onPressed: _busy || _selected.isEmpty
                        ? null
                        : () => _confirmAndPay(payAll: false),
                    child: const Text('Trả các khoản đã chọn',
                        textAlign: TextAlign.center),
                  )),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                      child: FilledButton(
                    onPressed: _busy ||
                            !(receivables.valueOrNull?.any((r) =>
                                    !r.isPaid && r.collectibleAmount > 0) ??
                                false)
                        ? null
                        : () => _confirmAndPay(payAll: true),
                    child: const Text('Trả toàn bộ công nợ',
                        textAlign: TextAlign.center),
                  )),
                ]),
              )),
    );
  }

  Future<void> _confirmAndPay({required bool payAll}) async {
    final all =
        ref.read(receivablesProvider).valueOrNull ?? const <Receivable>[];
    final rows = all
        .where((r) =>
            !r.isPaid &&
            r.collectibleAmount > 0 &&
            (payAll || _selected.contains(r.paymentId)))
        .toList();
    if (rows.isEmpty) return;
    final total = rows.fold<int>(0, (sum, r) => sum + r.collectibleAmount);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(payAll
            ? 'Xác nhận trả toàn bộ công nợ'
            : 'Xác nhận trả các khoản đã chọn'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                    'Máy chủ sẽ kiểm tra lại số tiền có thể thu của từng đơn. Khoản đang tranh chấp không được tính. Bạn sẽ được chuyển sang PayOS để hoàn tất thanh toán.'),
                const SizedBox(height: AppSpacing.md),
                ...rows.map((r) => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Row(children: <Widget>[
                        Expanded(child: Text(r.orderCode)),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                            child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(Money.format(r.collectibleAmount))))
                      ]),
                    )),
                const Divider(),
                Row(children: <Widget>[
                  const Expanded(
                      child: Text('Tổng thanh toán', style: AppText.cardTitle)),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(Money.format(total),
                              style: AppText.strong
                                  .copyWith(color: AppColors.primary))))
                ]),
              ],
            ))),
        actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xl),
        actions: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Thanh toán với PayOS'),
                ),
                const SizedBox(height: AppSpacing.s10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final checkout =
          await ref.read(financeRepositoryProvider).createDebtCheckout(
                payAll: payAll,
                paymentIds: rows.map((r) => r.paymentId).toList(),
                operationKey: const Uuid().v4(),
              );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DebtCheckoutResultScreen(initial: checkout)));
      _selected.clear();
      ref.invalidate(receivablesProvider);
    } catch (error) {
      if (mounted) {
        showAppSnack(context,
            'Không thể tạo thanh toán: ${ApiException.describe(error)}',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class DebtCheckoutResultScreen extends ConsumerWidget {
  const DebtCheckoutResultScreen({super.key, required this.initial});
  final DebtCheckout initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PayOsCheckoutResultPage(
        checkoutUrl: initial.checkoutUrl,
        initial: _debtSnapshot(initial),
        refresh: () async => _debtSnapshot(
            await ref.read(financeRepositoryProvider).debtCheckout(initial.id)),
        onTerminal: () => ref.invalidate(receivablesProvider),
        homeRoute: AppRoutes.rtOrders,
        reviewRoute: AppRoutes.rtPayments,
        reviewLabel: 'Xem lại công nợ',
        onReview: () {
          ref.invalidate(receivablesProvider);
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            context.go(AppRoutes.rtPayments);
          }
        },
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Đơn hàng thanh toán', style: AppText.cardTitle),
            const SizedBox(height: AppSpacing.s6),
            ...initial.allocations.map((allocation) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                  child: Row(children: <Widget>[
                    Expanded(child: Text(allocation.orderCode)),
                    Text(Money.format(allocation.amount),
                        style: AppText.cardTitle.copyWith(fontSize: 14)),
                  ]),
                )),
          ],
        ),
      );

  static PayOsCheckoutSnapshot _debtSnapshot(DebtCheckout checkout) =>
      PayOsCheckoutSnapshot(
        state: switch (checkout.status) {
          'Paid' => PayOsCheckoutState.paid,
          'Failed' => PayOsCheckoutState.failed,
          'Expired' => PayOsCheckoutState.expired,
          'Cancelled' => PayOsCheckoutState.cancelled,
          _ => PayOsCheckoutState.pending,
        },
        amount: checkout.amount,
        summary: '${checkout.allocations.length} khoản công nợ',
      );
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
        margin: EdgeInsets.zero,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: AppText.mutedSmall),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: AppText.display
                          .copyWith(fontSize: 18, color: color))),
            ]),
      );
}

class _ReceivableTile extends StatelessWidget {
  const _ReceivableTile(
      {required this.receivable, this.selected = false, this.onSelected});
  final Receivable receivable;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) {
    final r = receivable;
    final due =
        r.dueDate == null ? 'Chưa có hạn' : 'Hạn ${AppDates.date(r.dueDate)}';
    return AppCard(
      onTap: onSelected == null
          ? () => context.push(AppRoutes.rtOrderDetail(r.orderCode))
          : () => onSelected!(!selected),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        if (onSelected != null)
          Checkbox(
              value: selected,
              onChanged: (value) => onSelected!(value ?? false)),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Row(children: <Widget>[
                Expanded(child: Text(r.orderCode, style: AppText.strong)),
                StatusChip(label: r.status.label, tone: r.status.tone),
              ]),
              const SizedBox(height: AppSpacing.xxs),
              Text(due,
                  style: AppText.mutedSmall.copyWith(
                      color: r.isOverdue
                          ? AppColors.danger
                          : AppColors.textMuted)),
              Text(
                  r.method == 'Prepaid'
                      ? 'Trả trước'
                      : 'Công nợ ${r.term} ngày',
                  style: AppText.mutedSmall),
              if (r.collectibleAmount != r.outstandingAmount)
                Text(
                    'Đang tranh chấp: ${Money.format(r.outstandingAmount - r.collectibleAmount)}',
                    style: AppText.mutedSmall),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Text('Tổng cần thanh toán', style: AppText.mutedSmall),
                      Text(
                          Money.format(r.isPaid
                              ? r.confirmedAmount
                              : r.method == 'Prepaid'
                                  ? r.outstandingAmount
                                  : r.collectibleAmount),
                          style: AppText.strong.copyWith(
                              fontSize: 16, color: AppColors.primary)),
                    ]),
              ),
            ])),
      ]),
    );
  }
}
