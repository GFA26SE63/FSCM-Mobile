import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/enums.dart';
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
  Order? _result;

  Future<void> _confirm(Order o) async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final r = await ref
          .read(orderRepositoryProvider)
          .confirmReceipt(o.id, labelCodes: _scanned.toList());
      ref.invalidate(orderDetailProvider(o.id));
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
          final total = _scanned.length;
          final ready = total > 0;
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
                onCode: (c) => _onScan(o, c),
              ),
              if (_error.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                InfoBanner(
                    tone: StatusTone.danger,
                    icon: Icons.error_outline,
                    text: _error),
              ],
              SectionTitle('Tem đã quét (${_scanned.length})'),
              for (final c in _scanned)
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

  Widget _done(Order o) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        InfoBanner(
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
          title: 'Đã xác nhận nhận hàng ${o.code}',
          text: o.status == OrderStatus.delivered || o.status == OrderStatus.completed
              ? 'Đã nhận đủ mọi phần giao. Công nợ bắt đầu tính hạn từ ngày nhận đủ hàng.'
              : 'Đã nhận phần giao này. Đơn vẫn chờ các kho còn lại giao đủ.',
        ),
        FilledButton(
          onPressed: () =>
              context.pushReplacement(AppRoutes.rtOrderDetail(o.id)),
          child: const Text('Xem đơn hàng'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.rtComplaintFor(o.id)),
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
