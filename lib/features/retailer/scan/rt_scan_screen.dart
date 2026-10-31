import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Retailer "Quét QR" tab: scan a label printed on a carton, see which order
/// it belongs to and jump to receipt confirmation.
class RtScanScreen extends ConsumerStatefulWidget {
  const RtScanScreen({super.key});

  @override
  ConsumerState<RtScanScreen> createState() => _RtScanScreenState();
}

class _RtScanScreenState extends ConsumerState<RtScanScreen> {
  String _error = '';
  LabelInfo? _label;
  bool _canReceive = false;

  Future<void> _onScan(String raw) async {
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isLabel(code)) {
      setState(() {
        _label = null;
        _error = 'Mã "$code" không phải tem hàng (TEM-000000).';
      });
      return;
    }
    try {
      final label = await ref.read(warehouseRepositoryProvider).label(code);
      var canReceive = false;
      if (label.orderCode.isNotEmpty) {
        try {
          final order =
              await ref.read(orderRepositoryProvider).getOrder(label.orderCode);
          canReceive = order.status.canConfirmReceipt;
        } on ApiException {
          canReceive = false;
        }
      }
      if (!mounted) return;
      setState(() {
        _label = label;
        _canReceive = canReceive;
        _error = label.orderCode.isEmpty
            ? 'Tem $code chưa gắn với đơn hàng nào của bạn.'
            : '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _label = null;
        _error = e.statusCode == 403 || e.statusCode == 404
            ? 'Tem $code không thuộc đơn hàng của bạn.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _label;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR'),
        actions: const <Widget>[NotificationBellButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const InfoBanner(
            icon: Icons.qr_code_scanner,
            text:
                'Quét tem trên kiện hàng để kiểm tra đơn hàng và xác nhận nhận hàng.',
          ),
          QrScanView(
            onCode: _onScan,
          ),
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            InfoBanner(
                tone: StatusTone.danger,
                icon: Icons.error_outline,
                text: _error),
          ],
          if (l != null && l.orderCode.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                          child: Text(l.code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16))),
                      StatusChip(label: l.status.label, tone: l.status.tone),
                    ],
                  ),
                  KvRow('Sản phẩm', '${l.sku} · ${l.name}'),
                  KvRow('Số lượng', '${l.qty} thùng'),
                  KvRow('HSD', AppDates.date(l.expiry)),
                  KvRow('Thuộc đơn', l.orderCode, bold: true),
                  const SizedBox(height: 8),
                  if (_canReceive)
                    FilledButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.rtReceive(l.orderCode)),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Nhận hàng đơn này'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () =>
                          context.push(AppRoutes.rtOrderDetail(l.orderCode)),
                      child: const Text('Xem đơn hàng'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
