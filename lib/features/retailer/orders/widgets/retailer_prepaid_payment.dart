import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/payment_result.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/payos_checkout_result_page.dart';

class RetailerPrepaidPayment extends ConsumerStatefulWidget {
  const RetailerPrepaidPayment({super.key, required this.order});
  final Order order;
  @override
  ConsumerState<RetailerPrepaidPayment> createState() =>
      _RetailerPrepaidPaymentState();
}

class _RetailerPrepaidPaymentState
    extends ConsumerState<RetailerPrepaidPayment> {
  bool _busy = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(quotesApiProvider);
    try {
      final checkout = await api.createPayOsCheckout(widget.order.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PayOsCheckoutResultPage(
          checkoutUrl: checkout.checkoutUrl,
          initial: PayOsCheckoutSnapshot(
            state: _stateFromCode(checkout.status),
            amount: checkout.amount,
            summary: 'Đơn ${widget.order.code}',
          ),
          refresh: () async {
            final payment = await api.paymentForOrder(widget.order.id);
            return PayOsCheckoutSnapshot(
              state: _stateFromPayment(payment),
              amount: payment.amount,
              summary: 'Đơn ${widget.order.code}',
            );
          },
          onTerminal: () => ref.read(dataVersionProvider.notifier).state++,
          homeRoute: AppRoutes.rtOrders,
          reviewRoute: AppRoutes.rtOrderDetail(widget.order.code),
          reviewLabel: 'Xem lại đơn hàng',
        ),
      ));
      if (mounted) {
        ref.read(dataVersionProvider.notifier).state++;
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException &&
                error.code == 'payment_gateway_error'
            ? 'Kênh PayOS hiện chưa sẵn sàng. Vui lòng liên hệ nhà phân phối hoặc thử lại sau.'
            : ApiException.describe(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  static PayOsCheckoutState _stateFromPayment(PaymentResult payment) {
    if (payment.isPaid) return PayOsCheckoutState.paid;
    return _stateFromCode(payment.payOsLinkStatus ?? payment.status);
  }

  static PayOsCheckoutState _stateFromCode(String value) {
    return switch (value.toUpperCase()) {
      'PAID' => PayOsCheckoutState.paid,
      'CANCELLED' => PayOsCheckoutState.cancelled,
      'EXPIRED' => PayOsCheckoutState.expired,
      'FAILED' => PayOsCheckoutState.failed,
      _ => PayOsCheckoutState.pending,
    };
  }

  @override
  Widget build(BuildContext context) => AppCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Thanh toán trả trước',
              style: TextStyle(fontWeight: FontWeight.w800)),
          Text(
              'Số tiền cần thanh toán: ${Money.format(widget.order.finalAmount)}'),
          const Text(
              'PO và phiếu soạn được tạo sau khi hệ thống xác nhận đã thu đủ.'),
          if (_error != null)
            InfoBanner(tone: StatusTone.danger, text: _error!),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _pay,
            icon: const Icon(Icons.payments_outlined),
            label:
                Text(_busy ? 'Đang mở thanh toán...' : 'Thanh toán qua PayOS'),
          ),
          TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(dataVersionProvider.notifier).state++,
              child: const Text('Kiểm tra trạng thái thanh toán')),
        ],
      ));
}
