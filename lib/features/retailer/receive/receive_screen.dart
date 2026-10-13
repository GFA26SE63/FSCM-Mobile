import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receipt_confirmation.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Scan every label of the order, then confirm receipt. The server credits
/// loyalty points (or marks them pending for credit orders).
class RtReceiveScreen extends ConsumerStatefulWidget {
  const RtReceiveScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<RtReceiveScreen> createState() => _RtReceiveScreenState();
}

class _RtReceiveScreenState extends ConsumerState<RtReceiveScreen> {
  final Set<String> _scanned = <String>{};
  String _error = '';
  bool _busy = false;
  ReceiptConfirmation? _result;

  Future<void> _confirm(Order o) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref
          .read(orderRepositoryProvider)
          .confirmReceipt(o.code, labelCodes: _scanned.toList());
      ref.invalidate(orderDetailProvider(o.code));
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onScan(Order o, String raw) {
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isLabel(code)) {
      setState(() => _error = 'Mã "$code" không phải tem hàng (TEM-000000).');
      return;
    }
    if (!o.labelCodes.contains(code)) {
      setState(() => _error =
          'Tem $code không thuộc đơn ${o.code}. Kiểm tra lại kiện hàng.');
      return;
    }
    if (_scanned.contains(code)) {
      setState(() => _error = 'Tem $code đã quét rồi.');
      return;
    }
    setState(() {
      _scanned.add(code);
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(orderDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: Text('Nhận hàng · ${widget.code}')),
      body: AsyncBody<Order>(
        value: value,
        onRetry: () => ref.invalidate(orderDetailProvider(widget.code)),
        builder: (o) {
          if (_result != null) return _done(_result!);
          if (!o.status.canConfirmReceipt) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                InfoBanner(
                  icon: Icons.info_outline,
                  text:
                      'Đơn ${o.code} đang ở trạng thái "${o.status.label}" nên chưa thể xác nhận nhận hàng.',
                ),
                OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Quay lại')),
              ],
            );
          }
          final total = o.labelCodes.length;
          final ready = total > 0 && _scanned.length >= total;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const InfoBanner(
                icon: Icons.qr_code_scanner,
                text:
                    'Quét lần lượt tem QR dán trên từng kiện hàng của đơn để xác nhận đã nhận đủ.',
              ),
              QrScanView(
                hint: 'Quét tem trên kiện hàng',
                simulated: <SimulatedScan>[
                  for (final c in o.labelCodes)
                    if (!_scanned.contains(c)) SimulatedScan('Quét $c', c),
                  const SimulatedScan('Quét tem lạ TEM-000999', 'TEM-000999'),
                ],
                onCode: (c) => _onScan(o, c),
              ),
              if (_error.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                InfoBanner(
                    tone: StatusTone.danger,
                    icon: Icons.error_outline,
                    text: _error),
              ],
              SectionTitle('Tem đã quét (${_scanned.length}/$total)'),
              for (final c in o.labelCodes)
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _scanned.contains(c)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _scanned.contains(c)
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      const SizedBox(width: 10),
                      Text(c,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: ready && !_busy ? () => _confirm(o) : null,
                child:
                    Text(_busy ? 'Đang xác nhận...' : 'Xác nhận đã nhận hàng'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _done(ReceiptConfirmation r) {
    final o = r.order;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        InfoBanner(
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
          title: 'Đã xác nhận nhận hàng ${o.code}',
          text: r.pointsPending
              ? 'Đơn công nợ: ${r.order.pointsEarned > 0 ? r.order.pointsEarned : 'các'} điểm sẽ được cộng khi bạn thanh toán đủ.'
              : 'Bạn được cộng ${r.pointsEarned} điểm tích lũy.',
        ),
        FilledButton(
          onPressed: () =>
              context.pushReplacement(AppRoutes.rtOrderDetail(o.code)),
          child: const Text('Xem đơn hàng'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.rtComplaintFor(o.code)),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: const Text('Hàng thiếu / hư hỏng? Gửi khiếu nại'),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.rtLoyalty),
          child: const Text('Xem thẻ tích điểm'),
        ),
      ],
    );
  }
}
