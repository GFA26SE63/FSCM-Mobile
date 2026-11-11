import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/debt_checkout.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final Set<String> _selected = <String>{};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final receivables = ref.watch(receivablesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán & công nợ')),
      body: AsyncBody<List<Receivable>>(
        value: receivables,
        onRetry: () => ref.invalidate(receivablesProvider),
        builder: (all) {
          final open = all
              .where((r) =>
                  r.method == 'Credit' &&
                  !r.isPaid &&
                  !r.isCancelled &&
                  r.collectibleAmount > 0)
              .toList()
            ..sort((a, b) => (a.dueDate ?? DateTime(2100))
                .compareTo(b.dueDate ?? DateTime(2100)));
          final paid = all.where((r) => r.isPaid).toList();
          final openTotal =
              open.fold<int>(0, (sum, r) => sum + r.collectibleAmount);
          final selectedTotal = open
              .where((r) => _selected.contains(r.paymentId))
              .fold<int>(0, (sum, r) => sum + r.collectibleAmount);
          final prepaid = all
              .where((r) =>
                  r.method == 'Prepaid' &&
                  !r.isPaid &&
                  !r.isCancelled &&
                  r.outstandingAmount > 0)
              .toList();
          final overdue = open.where((r) => r.isOverdue).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(receivablesProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: <Widget>[
                Row(children: <Widget>[
                  Expanded(
                      child: _Summary(
                          label: 'Còn có thể trả',
                          value: Money.format(openTotal),
                          color: overdue.isEmpty
                              ? AppColors.text
                              : AppColors.danger)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Summary(
                          label: 'Đã chọn',
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
                const SectionTitle('Công nợ cần thanh toán'),
                if (open.isEmpty)
                  const SizedBox(
                      height: 140,
                      child: EmptyState(
                          title: 'Không có công nợ có thể thanh toán.',
                          icon: Icons.verified_outlined))
                else
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
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Row(children: <Widget>[
                Expanded(
                    child: OutlinedButton(
                  onPressed: _busy || _selected.isEmpty
                      ? null
                      : () => _confirmAndPay(payAll: false),
                  child: const Text('Thanh toán một phần'),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: FilledButton(
                  onPressed: _busy ||
                          !(receivables.valueOrNull?.any((r) =>
                                  !r.isPaid && r.collectibleAmount > 0) ??
                              false)
                      ? null
                      : () => _confirmAndPay(payAll: true),
                  child: const Text('Thanh toán hết'),
                )),
              ]),
            ),
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
        title: Text(
            payAll ? 'Xác nhận thanh toán hết' : 'Xác nhận thanh toán đã chọn'),
        content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                    'Máy chủ sẽ snapshot số tiền có thể thu của từng đơn. Khoản đang tranh chấp không được tính.'),
                const SizedBox(height: 12),
                ...rows.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: <Widget>[
                        Expanded(child: Text(r.orderCode)),
                        Text(Money.format(r.collectibleAmount))
                      ]),
                    )),
                const Divider(),
                Row(children: <Widget>[
                  const Expanded(
                      child: Text('Tổng thanh toán',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  Text(Money.format(total),
                      style: const TextStyle(fontWeight: FontWeight.w800))
                ]),
              ],
            )),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Quay lại')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Thanh toán với PayOS')),
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể tạo thanh toán: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class DebtCheckoutResultScreen extends ConsumerStatefulWidget {
  const DebtCheckoutResultScreen({super.key, required this.initial});
  final DebtCheckout initial;
  @override
  ConsumerState<DebtCheckoutResultScreen> createState() =>
      _DebtCheckoutResultScreenState();
}

class _DebtCheckoutResultScreenState
    extends ConsumerState<DebtCheckoutResultScreen>
    with WidgetsBindingObserver {
  late DebtCheckout _checkout;
  Timer? _timer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _checkout = widget.initial;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPayOs());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _openPayOs() async {
    final uri = Uri.tryParse(_checkout.checkoutUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở PayOS. Hãy thử lại.')));
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _checkout.isTerminal) return;
    _refreshing = true;
    try {
      final next =
          await ref.read(financeRepositoryProvider).debtCheckout(_checkout.id);
      if (mounted) setState(() => _checkout = next);
      if (next.isTerminal) {
        _timer?.cancel();
        ref.invalidate(receivablesProvider);
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = _checkout.status == 'Paid';
    final failed =
        _checkout.status == 'Failed' || _checkout.status == 'Expired';
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả thanh toán')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                  paid
                      ? Icons.check_circle
                      : failed
                          ? Icons.error_outline
                          : Icons.hourglass_top,
                  size: 72,
                  color: paid
                      ? AppColors.success
                      : failed
                          ? AppColors.danger
                          : AppColors.primary),
              const SizedBox(height: 16),
              Text(
                  paid
                      ? 'Thanh toán thành công'
                      : failed
                          ? (_checkout.status == 'Expired'
                              ? 'Thanh toán đã hết hạn'
                              : 'Thanh toán thất bại')
                          : 'Đang chờ PayOS xác nhận',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(Money.format(_checkout.amount),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text('${_checkout.allocations.length} khoản công nợ',
                  style: const TextStyle(color: AppColors.textMuted)),
              if (!paid && !failed) ...<Widget>[
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                TextButton(
                    onPressed: _openPayOs, child: const Text('Mở lại PayOS')),
              ],
              const Spacer(),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => context.go(AppRoutes.rtOrders),
                      child: const Text('Về trang chủ'))),
              const SizedBox(height: 10),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.rtPayments),
                      child: const Text('Xem lại công nợ'))),
            ]),
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
  Widget build(BuildContext context) => AppCard(
        margin: EdgeInsets.zero,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: color)),
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
      child: Row(children: <Widget>[
        if (onSelected != null)
          Checkbox(
              value: selected,
              onChanged: (value) => onSelected!(value ?? false)),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
              Text(r.orderCode,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(due,
                  style: TextStyle(
                      color:
                          r.isOverdue ? AppColors.danger : AppColors.textMuted,
                      fontSize: 13)),
              Text(
                  r.method == 'Prepaid'
                      ? 'Trả trước'
                      : 'Công nợ ${r.term} ngày',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              if (r.collectibleAmount != r.outstandingAmount)
                Text(
                    'Đang tranh chấp: ${Money.format(r.outstandingAmount - r.collectibleAmount)}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
            ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
          Text(
              Money.format(r.isPaid
                  ? r.confirmedAmount
                  : r.method == 'Prepaid'
                      ? r.outstandingAmount
                      : r.collectibleAmount),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          StatusChip(label: r.status.label, tone: r.status.tone),
        ]),
      ]),
    );
  }
}
