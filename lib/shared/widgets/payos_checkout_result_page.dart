import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

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
        padding: const EdgeInsets.all(AppSpacing.xxl),
        // Content scrolls (large fonts / small phones); actions stay pinned.
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: paid
                              ? AppColors.successSoft
                              : failed
                                  ? AppColors.dangerSoft
                                  : AppColors.primarySoft,
                        ),
                        child: Icon(
                          paid
                              ? Icons.check_rounded
                              : failed
                                  ? Icons.error_outline
                                  : Icons.hourglass_top,
                          size: 40,
                          color: paid
                              ? AppColors.success
                              : failed
                                  ? AppColors.danger
                                  : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(title,
                          textAlign: TextAlign.center, style: AppText.display),
                      const SizedBox(height: AppSpacing.sm),
                      Text(Money.format(_snapshot.amount),
                          style: AppText.display.copyWith(
                              fontSize: 24, color: AppColors.primary)),
                      Text(_snapshot.summary,
                          textAlign: TextAlign.center, style: AppText.muted),
                      if (widget.details != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        widget.details!,
                      ],
                      if (!paid && !failed) ...<Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        const CircularProgressIndicator(),
                        TextButton(
                            onPressed: _openPayOs,
                            child: const Text('Mở lại PayOS')),
                        TextButton(
                            onPressed: _refresh,
                            child: const Text('Kiểm tra trạng thái ngay')),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () => context.go(widget.homeRoute),
                  child: const Text('Về trang chủ')),
            ),
            const SizedBox(height: AppSpacing.s10),
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
