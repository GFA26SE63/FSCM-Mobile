import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

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
              const Text(
                  'Mở trang PayOS để thanh toán, sau đó quay lại app và kiểm tra trạng thái.'),
              const SizedBox(height: 12),
              SelectableText(checkout.checkoutUrl),
            ],
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Đóng')),
            FilledButton(
              onPressed: uri == null || !['https', 'http'].contains(uri.scheme)
                  ? null
                  : () async {
                      final opened = await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                      if (!opened && dialogContext.mounted) {
                        showAppSnack(dialogContext,
                            'Không mở được trang thanh toán. Hãy sao chép liên kết.',
                            error: true);
                      }
                    },
              child: const Text('Mở trang thanh toán'),
            ),
          ],
        ),
      );
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
