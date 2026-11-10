import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/quote_payment_sheet.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

class RetailerQuotePanel extends ConsumerStatefulWidget {
  const RetailerQuotePanel({super.key, required this.order});
  final Order order;

  @override
  ConsumerState<RetailerQuotePanel> createState() => _RetailerQuotePanelState();
}

class _RetailerQuotePanelState extends ConsumerState<RetailerQuotePanel> {
  bool _busy = false;
  String? _error;
  Timer? _expiryTimer;
  String? _expiryKey;

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _watchExpiry(SalesOrderQuote quote) {
    final key =
        '${quote.id}:${quote.version}:${quote.expiresAt.toIso8601String()}';
    if (_expiryKey == key) {
      return;
    }
    _expiryKey = key;
    _expiryTimer?.cancel();
    final remaining = quote.expiresAt.difference(AppClock.now());
    if (remaining > Duration.zero && quote.status == 'Issued') {
      _expiryTimer = Timer(remaining + const Duration(milliseconds: 1), () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => AsyncBody<List<SalesOrderQuote>>(
        value: ref.watch(orderQuotesProvider(widget.order.id)),
        onRetry: () => ref.invalidate(orderQuotesProvider(widget.order.id)),
        builder: (rows) {
          final quote = SalesOrderQuote.latestForOrder(rows, widget.order.id);
          if (quote == null) {
            return const InfoBanner(
                tone: StatusTone.warning,
                text: 'Chưa có báo giá cho đơn này. Hãy tải lại để cập nhật.');
          }
          _watchExpiry(quote);
          final canDecide =
              quote.canDecide && widget.order.status == OrderStatus.quoted;
          return AppCard(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Báo giá chính thức #${quote.revisionNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(Money.format(quote.totalAmount),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text(
                  'Hạn phản hồi ${AppDates.timeDay(quote.expiresAt.toLocal())}'),
              if (!canDecide)
                InfoBanner(
                    tone: StatusTone.warning,
                    text: quote.status == 'Accepted'
                        ? 'Báo giá đã được chấp nhận. Tải lại đơn để xem thanh toán và PO.'
                        : quote.status == 'Rejected'
                            ? 'Bạn đã từ chối báo giá này.'
                            : 'Báo giá đã hết hạn hoặc không còn chờ quyết định. Hãy tải lại đơn.'),
              if (quote.purchaseOrderCode != null)
                Text('PO: ${quote.purchaseOrderCode}'),
              if (quote.rejectionReason?.isNotEmpty == true)
                Text(quote.rejectionReason!),
              if (_error != null)
                InfoBanner(tone: StatusTone.danger, text: _error!),
              FilledButton(
                onPressed: !canDecide || _busy ? null : () => _accept(quote),
                child: Text(
                    _busy ? 'Đang xử lý...' : 'Chấp nhận và chọn thanh toán'),
              ),
              TextButton(
                onPressed: !canDecide || _busy ? null : () => _reject(quote),
                child: const Text('Từ chối báo giá'),
              ),
            ],
          ));
        },
      );

  Future<void> _accept(SalesOrderQuote quote) async {
    final actions = ref.read(retailerOrderActionsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final method = await showModalBottomSheet<PaymentMethod>(
        context: context,
        isScrollControlled: true,
        builder: (_) => QuotePaymentSheet(order: widget.order, quote: quote),
      );
      if (!mounted || method == null) {
        return;
      }
      await actions.accept(widget.order, quote, method);
      if (mounted) {
        showAppSnack(
            context,
            method == PaymentMethod.prepaid
                ? 'Đã chấp nhận báo giá. Mở thanh toán trả trước để tiếp tục.'
                : 'Đã chấp nhận báo giá theo công nợ. Đang cập nhật tiến trình đơn.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = ApiException.describe(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reject(SalesOrderQuote quote) async {
    final actions = ref.read(retailerOrderActionsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final reason = await showDialog<String>(
          context: context, builder: (_) => const _RejectQuoteDialog());
      if (!mounted || reason == null) {
        return;
      }
      await actions.reject(widget.order, quote, reason);
      if (mounted) {
        showAppSnack(context, 'Đã từ chối báo giá.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = ApiException.describe(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _RejectQuoteDialog extends StatefulWidget {
  const _RejectQuoteDialog();
  @override
  State<_RejectQuoteDialog> createState() => _RejectQuoteDialogState();
}

class _RejectQuoteDialogState extends State<_RejectQuoteDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Từ chối báo giá'),
        content: Form(
            key: _form,
            child: TextFormField(
              controller: _reason,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Lý do'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập lý do.'
                  : null,
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Quay lại')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.of(context).pop(_reason.text.trim());
                }
              },
              child: const Text('Từ chối')),
        ],
      );
}
