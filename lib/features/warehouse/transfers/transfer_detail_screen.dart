import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Transfer slip detail. While in transit the keeper scans every label of the
/// slip, then confirms receipt (`POST /transfers/{code}/receive`).
class TransferDetailScreen extends ConsumerStatefulWidget {
  const TransferDetailScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<TransferDetailScreen> createState() =>
      _TransferDetailScreenState();
}

class _TransferDetailScreenState extends ConsumerState<TransferDetailScreen> {
  final Set<String> _scanned = <String>{};
  String _error = '';
  bool _busy = false;
  bool _scanning = false;

  void _onScan(Transfer t, String raw) {
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isLabel(code)) {
      setState(() => _error = 'Mã "$code" không phải tem (TEM-000000).');
      return;
    }
    final expected = t.lines.map((l) => l.labelCode).toSet();
    if (!expected.contains(code)) {
      setState(() => _error =
          'Tem $code không thuộc phiếu ${t.code}. Kiểm tra lại hàng hóa.');
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

  Future<void> _receive(Transfer t) async {
    final ok = await confirmDialog(
      context,
      title: 'Xác nhận nhận hàng',
      message:
          'Nhập ${t.totalQty} thùng từ ${t.fromWarehouse} vào ${t.toWarehouse}?',
      confirmLabel: 'Nhận hàng',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(warehouseRepositoryProvider)
          .receiveTransfer(t.code, _scanned.toList());
      ref.invalidate(transferDetailProvider(widget.code));
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) {
        setState(() => _scanning = false);
        showAppSnack(context, 'Đã nhận hàng theo phiếu ${t.code}.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(transferDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: Text('Phiếu ${widget.code}')),
      body: AsyncBody<Transfer>(
        value: value,
        onRetry: () => ref.invalidate(transferDetailProvider(widget.code)),
        builder: _content,
      ),
    );
  }

  Widget _content(Transfer t) {
    final inTransit = t.status == TransferStatus.inTransit;
    final done = _scanned.length >= t.lines.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(t.code,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  StatusChip(label: t.status.label, tone: t.status.tone),
                ],
              ),
              const SizedBox(height: 6),
              KvRow('Loại phiếu', t.kind.label),
              KvRow('Từ kho', t.fromWarehouse),
              KvRow('Đến kho', t.toWarehouse),
              KvRow('Xuất kho', AppDates.timeDay(t.shippedAt)),
              if (t.status == TransferStatus.received)
                KvRow('Đã nhận', AppDates.timeDay(t.receivedAt))
              else
                KvRow('Dự kiến đến', AppDates.timeDay(t.expectedAt)),
              if (t.distanceKm > 0)
                KvRow('Quãng đường', '${t.distanceKm.toStringAsFixed(0)} km'),
            ],
          ),
        ),
        if (t.isNearExpiry)
          const InfoBanner(
            tone: StatusTone.warning,
            icon: Icons.schedule,
            title: 'Luân chuyển cận hạn',
            text:
                'Lô gần hết hạn được chuyển sang kho có nhu cầu bán nhanh hơn. Ưu tiên xếp lên kệ FEFO.',
          ),
        if (t.note.isNotEmpty) InfoBanner(icon: Icons.notes, text: t.note),
        SectionTitle(
            'Hàng trong phiếu (${t.lines.length} tem · ${t.totalQty} thùng)'),
        for (final l in t.lines) _lineCard(l, inTransit),
        if (inTransit) ...<Widget>[
          if (_error.isNotEmpty)
            InfoBanner(
                tone: StatusTone.danger,
                icon: Icons.error_outline,
                text: _error),
          if (_scanning) ...<Widget>[
            const SectionTitle('Quét tem từng kiện'),
            QrScanView(
              hint: 'Quét tem trên kiện hàng',
              simulated: <SimulatedScan>[
                for (final l in t.lines)
                  if (!_scanned.contains(l.labelCode))
                    SimulatedScan('Quét ${l.labelCode}', l.labelCode),
                const SimulatedScan('Quét tem lạ TEM-000999', 'TEM-000999'),
              ],
              onCode: (c) => _onScan(t, c),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _busy
                ? null
                : done
                    ? () => _receive(t)
                    : (_scanning
                        ? null
                        : () => setState(() => _scanning = true)),
            icon:
                Icon(done ? Icons.inventory_2_outlined : Icons.qr_code_scanner),
            label: Text(
              done
                  ? (_busy ? 'Đang xử lý...' : 'Xác nhận nhận hàng')
                  : 'Quét tem để nhận (${_scanned.length}/${t.lines.length})',
            ),
          ),
        ],
      ],
    );
  }

  Widget _lineCard(TransferLine l, bool inTransit) {
    final ok = l.received || _scanned.contains(l.labelCode);
    return AppCard(
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            color: ok ? AppColors.primary : AppColors.border,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${l.sku} · ${l.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Batch ${l.batchCode}',
                    style: const TextStyle(fontSize: 13)),
                Text(
                  'HSD ${AppDates.date(l.expiry)} · ${l.labelCode}',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text('${l.qty} thùng',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
