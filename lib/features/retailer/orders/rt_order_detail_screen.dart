import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';

/// Retailer order detail: delivery vehicle + driver, lines with batches,
/// promotions, timeline, and the receipt-confirmation entry point.
class RtOrderDetailScreen extends ConsumerWidget {
  const RtOrderDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text(code)),
      body: AsyncBody<Order>(
        value: value,
        onRetry: () => ref.invalidate(orderDetailProvider(code)),
        builder: (o) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: Text(o.code,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
                OrderStatusChip(o),
              ],
            ),
            const SizedBox(height: 4),
            Text('Đặt lúc ${AppDates.timeDay(o.createdAt)}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (o.status.isRejectedOrCancelled)
              InfoBanner(
                tone: StatusTone.danger,
                icon: Icons.block,
                title: 'Đơn bị từ chối',
                text: o.rejectReason.isEmpty
                    ? 'Hệ thống từ chối đơn hàng.'
                    : o.rejectReason,
              ),
            if (o.status == OrderStatus.quoted) _QuoteDecision(order: o),
            if (o.canPayOnline) _PrepaidPayment(order: o),
            if (o.hasDelivery) DeliveryInfoCard(o),
            if (o.status.canConfirmReceipt)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.rtReceive(o.id)),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Quét QR nhận hàng'),
                ),
              ),
            if (o.status == OrderStatus.delivered ||
                o.status == OrderStatus.completed)
              _receiptBanner(o),
            const SectionTitle('Sản phẩm'),
            OrderLinesCard(o, showBatches: !o.status.isRejectedOrCancelled),
            const SectionTitle('Khuyến mãi áp dụng'),
            AppliedPromoCard(o.appliedPromos,
                emptyText: 'Không có khuyến mãi.'),
            const SizedBox(height: 10),
            TotalsCard(total: o.total, discount: o.discount),
            const SectionTitle('Thanh toán'),
            AppCard(
              child: Column(
                children: <Widget>[
                  KvRow('Hình thức', o.payment.labelWithTerm(o.creditTerm)),
                  if (o.payment == PaymentMethod.credit && o.dueDate != null)
                    KvRow('Hạn thanh toán', AppDates.date(o.dueDate)),
                  KvRow(
                    'Trạng thái',
                    o.paid
                        ? (o.paidAt == null ? 'Đã thanh toán' : 'Đã thanh toán ${AppDates.timeDay(o.paidAt)}')
                        : 'Chưa thanh toán',
                  ),
                ],
              ),
            ),
            if (o.timeline.isNotEmpty) ...<Widget>[
              const SectionTitle('Tiến trình'),
              AppCard(child: TimelineList(o.timeline)),
            ],
            if (o.status == OrderStatus.delivered ||
                o.status == OrderStatus.completed)
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.rtComplaintFor(o.id)),
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Khiếu nại đơn hàng'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _receiptBanner(Order o) {
    if (o.pointsEarned <= 0) return const SizedBox.shrink();
    return InfoBanner(
      tone: StatusTone.success,
      icon: Icons.stars_outlined,
      title: o.pointsPending
          ? '+${o.pointsEarned} điểm đang chờ cộng'
          : '+${o.pointsEarned} điểm đã cộng',
      text: o.pointsPending
          ? 'Đơn công nợ: điểm được cộng khi bạn thanh toán đủ.'
          : 'Điểm tích lũy từ đơn hàng này đã vào tài khoản.',
    );
  }
}

class _QuoteDecision extends ConsumerWidget {
  const _QuoteDecision({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(orderQuotesProvider(order.id));
    return AsyncBody(
      value: quotes,
      onRetry: () => ref.invalidate(orderQuotesProvider(order.id)),
      builder: (rows) {
        final pending = rows.where((quote) => quote.canDecide).toList();
        if (pending.isEmpty) {
          return const InfoBanner(
            tone: StatusTone.warning,
            text: 'Báo giá chưa sẵn sàng hoặc đã hết hạn. Hãy tải lại đơn hàng.',
          );
        }
        final quote = pending.first;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Báo giá chính thức',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              Text(Money.format(quote.totalAmount),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Hết hạn ${AppDates.timeDay(quote.expiresAt)}',
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => _choosePayment(context, ref, quote),
                child: const Text('Chấp nhận và chọn thanh toán'),
              ),
              TextButton(
                onPressed: () => _reject(context, ref, quote),
                child: const Text('Từ chối báo giá'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _choosePayment(
      BuildContext context, WidgetRef ref, SalesOrderQuote quote) async {
    final payment = await showModalBottomSheet<PaymentMethod>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Chọn phương thức thanh toán',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Text('Không áp dụng COD.'),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Trả trước'),
                subtitle: const Text('Thanh toán xong hệ thống mới sinh PO và phiếu soạn.'),
                onTap: () => Navigator.pop(context, PaymentMethod.prepaid),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('Công nợ'),
                subtitle: const Text('Chỉ áp dụng khi Retailer có kỳ hạn được duyệt.'),
                onTap: () => Navigator.pop(context, PaymentMethod.credit),
              ),
            ],
          ),
        ),
      ),
    );
    if (payment == null || !context.mounted) return;
    try {
      final api = ref.read(quotesApiProvider);
      await api.accept(quote, payment);
      ref.invalidate(orderQuotesProvider(order.id));
      ref.read(dataVersionProvider.notifier).state++;
      if (!context.mounted) return;
      if (payment == PaymentMethod.prepaid) {
        showAppSnack(context,
            'Đã chọn trả trước. Bấm Thanh toán qua PayOS trên chi tiết đơn để tiếp tục.');
      } else {
        showAppSnack(context,
            'Đã xác nhận công nợ. Hệ thống đã chuyển SO đủ điều kiện thành PO.');
      }
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, SalesOrderQuote quote) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối báo giá'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Lý do'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Quay lại')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !context.mounted) return;
    try {
      await ref.read(quotesApiProvider).reject(quote, reason);
      ref.invalidate(orderQuotesProvider(order.id));
      ref.invalidate(orderDetailProvider(order.id));
      ref.read(dataVersionProvider.notifier).state++;
    } on ApiException catch (error) {
      if (context.mounted) showAppSnack(context, error.message, error: true);
    }
  }
}


class _PrepaidPayment extends ConsumerStatefulWidget {
  const _PrepaidPayment({required this.order});
  final Order order;

  @override
  ConsumerState<_PrepaidPayment> createState() => _PrepaidPaymentState();
}

class _PrepaidPaymentState extends ConsumerState<_PrepaidPayment> {
  bool _busy = false;
  String? _error;

  Future<void> _pay() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _openPrepaidCheckout(context, ref, widget.order.id);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.code == 'payment_gateway_error'
            ? 'Kênh PayOS hiện chưa sẵn sàng. Vui lòng liên hệ nhà phân phối hoặc thử lại sau.'
            : error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Thanh toán trả trước',
            style: TextStyle(fontWeight: FontWeight.w800)),
        Text('Số tiền cần thanh toán: ${Money.format(widget.order.finalAmount)}'),
        const Text('PO và phiếu soạn được tạo sau khi hệ thống xác nhận đã thu đủ.'),
        if (_error != null) InfoBanner(tone: StatusTone.danger, text: _error!),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _pay,
          icon: const Icon(Icons.payments_outlined),
          label: Text(_busy ? 'Đang mở thanh toán...' : 'Thanh toán qua PayOS'),
        ),
        TextButton(
          onPressed: _busy ? null : () => ref.read(dataVersionProvider.notifier).state++,
          child: const Text('Kiểm tra trạng thái thanh toán'),
        ),
      ],
    ),
  );
}

Future<void> _openPrepaidCheckout(
    BuildContext context, WidgetRef ref, String orderId) async {
  final checkout = await ref.read(quotesApiProvider).createPayOsCheckout(orderId);
  if (!context.mounted) return;
  final uri = Uri.tryParse(checkout.checkoutUrl);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Thanh toán qua PayOS'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mở trang PayOS để quét QR hoặc chuyển khoản. Sau đó quay lại app và kiểm tra trạng thái.'),
            const SizedBox(height: 12),
            SelectableText(checkout.checkoutUrl),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: uri == null || !['https', 'http'].contains(uri.scheme) ? null : () async {
            final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!opened && dialogContext.mounted) {
              showAppSnack(dialogContext, 'Không mở được trang thanh toán. Hãy sao chép liên kết phía trên.', error: true);
            }
          },
          child: const Text('Mở trang thanh toán'),
        ),
      ],
    ),
  );
  if (context.mounted) ref.read(dataVersionProvider.notifier).state++;
}
