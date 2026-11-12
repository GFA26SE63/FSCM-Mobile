import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';

enum PayOsCheckoutState { pending, paid, failed, expired, cancelled }

class PayOsCheckoutSnapshot {
  const PayOsCheckoutSnapshot({
    required this.state,
    required this.amount,
    required this.summary,
  });

  final PayOsCheckoutState state;
  final num amount;
  final String summary;

  bool get isTerminal => state != PayOsCheckoutState.pending;
}

typedef PayOsCheckoutRefresher = Future<PayOsCheckoutSnapshot> Function();
typedef PayOsUrlOpener = Future<bool> Function(Uri uri);

/// Shared PayOS handoff page for prepaid orders and debt settlement.
/// The webhook is authoritative; polling recovers delayed callback delivery.
class PayOsCheckoutResultPage extends StatefulWidget {
  const PayOsCheckoutResultPage({
    super.key,
    required this.checkoutUrl,
    required this.initial,
    required this.refresh,
    required this.homeRoute,
    required this.reviewRoute,
    required this.reviewLabel,
    this.onTerminal,
    this.openUrl,
    this.details,
    this.onReview,
  });

  final String checkoutUrl;
  final PayOsCheckoutSnapshot initial;
  final PayOsCheckoutRefresher refresh;
  final String homeRoute;
  final String reviewRoute;
  final String reviewLabel;
  final VoidCallback? onTerminal;
  final PayOsUrlOpener? openUrl;
  final Widget? details;
  final VoidCallback? onReview;

  @override
  State<PayOsCheckoutResultPage> createState() =>
      _PayOsCheckoutResultPageState();
}

class _PayOsCheckoutResultPageState extends State<PayOsCheckoutResultPage>
    with WidgetsBindingObserver {
  late PayOsCheckoutSnapshot _snapshot;
  Timer? _timer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initial;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) => _openPayOs());
    if (!_snapshot.isTerminal) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _openPayOs() async {
    final uri = Uri.tryParse(widget.checkoutUrl);
    final opener = widget.openUrl ??
        (value) => launchUrl(value, mode: LaunchMode.externalApplication);
    if (uri == null || !await opener(uri)) {
      if (mounted) {
        showAppSnack(context, 'Không thể mở PayOS. Hãy thử lại.', error: true);
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _snapshot.isTerminal) return;
    _refreshing = true;
    try {
      final next = await widget.refresh();
      if (!mounted) return;
      setState(() => _snapshot = next);
      if (next.isTerminal) {
        _timer?.cancel();
        widget.onTerminal?.call();
      }
    } catch (_) {
      // Keep the page usable during a transient network failure; retry on the
      // next timer tick or when the app resumes from PayOS.
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
    final state = _snapshot.state;
    final paid = state == PayOsCheckoutState.paid;
    final failed = state == PayOsCheckoutState.failed ||
        state == PayOsCheckoutState.expired ||
        state == PayOsCheckoutState.cancelled;
    final title = switch (state) {
      PayOsCheckoutState.paid => 'Thanh toán thành công',
      PayOsCheckoutState.expired => 'Thanh toán đã hết hạn',
      PayOsCheckoutState.cancelled => 'Thanh toán đã hủy',
      PayOsCheckoutState.failed => 'Thanh toán thất bại',
      PayOsCheckoutState.pending => 'Đang chờ PayOS xác nhận',
    };
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
                      : AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(Money.format(_snapshot.amount),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(_snapshot.summary,
                style: const TextStyle(color: AppColors.textMuted)),
            if (widget.details != null) ...<Widget>[
              const SizedBox(height: 16),
              widget.details!,
            ],
            if (!paid && !failed) ...<Widget>[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              TextButton(
                  onPressed: _openPayOs, child: const Text('Mở lại PayOS')),
              TextButton(
                  onPressed: _refresh,
                  child: const Text('Kiểm tra trạng thái ngay')),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => context.go(widget.homeRoute),
                  child: const Text('Về trang chủ')),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed:
                      widget.onReview ?? () => context.go(widget.reviewRoute),
                  child: Text(widget.reviewLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
