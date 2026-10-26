import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/quantity.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';

/// F44: scan the source label of one gather and take cartons off it.
///
/// The gather fixes the batch. A label from another batch is refused rather
/// than offered as an alternative, because the batch is what the allocation and
/// its approved price were decided on.
///
/// What is taken is then apportioned across the orders waiting on this gather,
/// in the order the server returned them - that order is the run's own
/// priority, so filling it front to back is what keeps first come first served.
class PickLineScreen extends ConsumerStatefulWidget {
  const PickLineScreen({
    super.key,
    required this.code,
    required this.gatherId,
  });

  final String code;
  final String gatherId;

  @override
  ConsumerState<PickLineScreen> createState() => _PickLineScreenState();
}

class _PickLineScreenState extends ConsumerState<PickLineScreen> {
  LabelInfo? _label;
  String _error = '';
  int _qty = 0;
  bool _busy = false;
  bool _done = false;

  /// One key per scan the keeper is making, created when the quantity screen
  /// opens and reused on every retry of that same scan. A fresh key per attempt
  /// would turn a lost reply into a second deduction, which is the one thing
  /// idempotency is here to prevent.
  String? _operationKey;

  Future<void> _onScan(RunPickingGather gather, String raw) async {
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isLabel(code)) {
      setState(() => _error = 'Mã "$code" không phải tem (TEM-000000).');
      return;
    }
    try {
      final label = await ref.read(warehouseRepositoryProvider).label(code);
      if (!mounted) return;
      if (label.sku != gather.sku || label.batchCode != gather.batchCode) {
        setState(() {
          _label = null;
          _error = 'Sai tem: $code thuộc ${label.sku} · ${label.batchCode}. '
              'Lượt lấy này cần ${gather.sku} · batch ${gather.batchCode}, '
              'và batch đã được phương án duyệt nên không thể đổi.';
        });
        return;
      }
      final remaining = gather.remainingQuantity;
      setState(() {
        _label = label;
        _error = '';
        _operationKey = const Uuid().v4();
        _qty = remaining < label.qty ? remaining.floor() : label.qty;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _confirm(RunPickingSheet sheet, RunPickingGather gather) async {
    final label = _label;
    final key = _operationKey;
    if (label == null || key == null || _qty <= 0) return;
    final splits = gather.apportion(_qty.toDouble());
    if (splits.isEmpty) {
      setState(
          () => _error = 'Lượt lấy này đã đủ, không còn đơn nào cần chia.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(warehouseRepositoryProvider).pick(
            widget.code,
            operationKey: key,
            qrCode: label.code,
            expectedPickingVersion: sheet.version,
            expectedLabelVersion: label.version,
            splits: splits,
            quantity: _qty.toDouble(),
          );
      ref.invalidate(pickingDetailProvider(widget.code));
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(pickingDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: Text('Lấy hàng · ${widget.code}')),
      body: AsyncBody<RunPickingSheet>(
        value: value,
        onRetry: () => ref.invalidate(pickingDetailProvider(widget.code)),
        builder: (sheet) {
          RunPickingGather? found;
          for (final candidate in sheet.gathers) {
            if (candidate.id == widget.gatherId) {
              found = candidate;
              break;
            }
          }
          if (found == null) {
            return const Center(
                child: Text('Không tìm thấy lượt lấy trên phiếu này.'));
          }
          final gather = found;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(gather.sku,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Batch ${gather.batchCode}',
                        style: const TextStyle(color: AppColors.textMuted)),
                    Text(
                        'Cần lấy ${Qty.cartons(gather.requiredQuantity)} · '
                        'đã lấy ${Qty.format(gather.pickedQuantity)} · '
                        'còn ${Qty.format(gather.remainingQuantity)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Sẽ chia về',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted)),
                    for (final split in gather.outstanding)
                      Text(
                          '${split.orderCode}: còn ${Qty.cartons(split.remainingQuantity)}'),
                  ],
                ),
              ),
              if (_done)
                _resultView(gather)
              else ...<Widget>[
                if (_label == null)
                  QrScanView(
                    hint: 'Quét tem thuộc batch ${gather.batchCode}',
                    onCode: (c) => _onScan(gather, c),
                  )
                else
                  _quantityView(sheet, gather, _label!),
                if (_error.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  InfoBanner(
                      tone: StatusTone.danger,
                      icon: Icons.error_outline,
                      text: _error),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _quantityView(
      RunPickingSheet sheet, RunPickingGather gather, LabelInfo label) {
    final remaining = gather.remainingQuantity;
    final max = (remaining < label.qty ? remaining.floor() : label.qty);
    final whole = _qty == label.qty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Tem nguồn ${label.code}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Đang có ${label.qty} thùng · ${label.location}'),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 6, 2, 6),
          child: Text('Số thùng thực lấy',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        Center(
            child: QuantityStepper(
                value: _qty,
                min: 1,
                max: max < 1 ? 1 : max,
                step: 1,
                onChanged: (v) => setState(() => _qty = v))),
        const SizedBox(height: 10),
        InfoBanner(
          icon: Icons.call_split,
          title: 'Kết quả sau khi xác nhận',
          text: whole
              ? 'Lấy nguyên tem ${label.code} (${label.qty} thùng).'
              : 'Tách tem con mới $_qty thùng. Tem gốc ${label.code} còn ${label.qty - _qty} thùng ở lại kệ.',
        ),
        FilledButton(
            onPressed: _busy ? null : () => _confirm(sheet, gather),
            child: Text(_busy ? 'Đang xử lý...' : 'Xác nhận số lượng')),
        TextButton(
            onPressed: () => setState(() {
                  _label = null;
                  _operationKey = null;
                }),
            child: const Text('Quét tem khác')),
      ],
    );
  }

  Widget _resultView(RunPickingGather gather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 10),
        InfoBanner(
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
          title: 'Đã ghi $_qty thùng vào phiếu',
          text: gather.isDone
              ? 'Lượt lấy ${gather.batchCode} đã đủ.'
              : 'Lượt lấy ${gather.batchCode} còn ${Qty.cartons(gather.remainingQuantity)}.',
        ),
        FilledButton(
            onPressed: () => context.pop(), child: const Text('Về phiếu soạn')),
      ],
    );
  }
}
