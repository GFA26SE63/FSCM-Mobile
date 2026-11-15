import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/printing/label_printer.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';

/// Scan the source label of a picking line, choose how many cartons to take
/// (splitting the label when needed) and confirm.
class PickLineScreen extends ConsumerStatefulWidget {
  const PickLineScreen(
      {super.key, required this.code, required this.lineIndex});

  final String code;
  final int lineIndex;

  @override
  ConsumerState<PickLineScreen> createState() => _PickLineScreenState();
}

class _PickLineScreenState extends ConsumerState<PickLineScreen> {
  LabelInfo? _label;
  String _error = '';
  int _qty = 0;
  bool _busy = false;
  bool _printing = false;
  PickScanResult? _result;

  Future<void> _print(String code) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await ref.read(labelPrinterProvider).printLabel(code);
      if (mounted) {
        showAppSnack(context,
            'Đã mở hộp thoại in tem $code. Chọn máy in và xác nhận in.');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } on UnsupportedError catch (error) {
      if (mounted) {
        showAppSnack(
            context, error.message ?? 'Chưa hỗ trợ in trên thiết bị này.',
            error: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context,
            'Không mở được hộp thoại in. Thử lại hoặc in các tem mới từ Portal.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _onScan(PickingLine line, String raw) async {
    final code = raw.trim().toUpperCase();
    if (!IdFormat.isLabel(code)) {
      setState(() => _error = 'Mã "$code" không phải tem (TEM-000000).');
      return;
    }
    try {
      final label = await ref.read(warehouseRepositoryProvider).label(code);
      if (!mounted) return;
      if (label.status != LabelStatus.available) {
        setState(() {
          _label = null;
          _error =
              'Tem $code không còn sẵn sàng. Nếu đã tách, hãy quét tem thay thế mới.';
        });
        return;
      }
      if (label.sku != line.sku || label.batchCode != line.batchCode) {
        setState(() {
          _label = null;
          _error =
              'Sai tem: $code thuộc ${label.sku} · ${label.batchCode}. Dòng này cần ${line.sku} · ${line.batchCode} (tem gợi ý ${line.suggestedLabel}).';
        });
        return;
      }
      final remaining = line.need - line.picked;
      setState(() {
        _label = label;
        _error = '';
        _qty = remaining < label.qty ? remaining : label.qty;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _confirm(PickingLine line) async {
    final label = _label;
    if (label == null || _qty <= 0 || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(warehouseRepositoryProvider).pick(
            widget.code,
            allocationId: line.allocationId,
            labelCode: label.code,
            qty: _qty,
            sourceLabelQty: label.qty,
            pickingVersion: ref
                    .read(pickingDetailProvider(widget.code))
                    .valueOrNull
                    ?.version ??
                0,
            labelVersion: label.version,
          );
      ref.invalidate(pickingDetailProvider(widget.code));
      ref.read(dataVersionProvider.notifier).state++;
      if (mounted) setState(() => _result = result);
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
      body: AsyncBody<PickingList>(
        value: value,
        onRetry: () => ref.invalidate(pickingDetailProvider(widget.code)),
        builder: (list) {
          if (widget.lineIndex < 0 || widget.lineIndex >= list.lines.length) {
            return const Center(child: Text('Không tìm thấy dòng cần lấy.'));
          }
          final line = list.lines[widget.lineIndex];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${line.sku} · ${line.name}',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                        'Batch ${line.batchCode} · HSD ${AppDates.date(line.expiry)} · vị trí ${line.location}'),
                    Text('Cần lấy ${line.need} thùng (đã lấy ${line.picked})',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (_result != null)
                _resultView(_result!)
              else ...<Widget>[
                if (_label == null) ...<Widget>[
                  QrScanView(
                    hint: 'Quét tem nguồn ${line.suggestedLabel}',
                    onCode: (c) => _onScan(line, c),
                  ),
                ] else
                  _quantityView(line, _label!),
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

  Widget _quantityView(PickingLine line, LabelInfo label) {
    final remaining = line.need - line.picked;
    final max = remaining < label.qty ? remaining : label.qty;
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
                max: max,
                step: 1,
                onChanged: (v) => setState(() => _qty = v))),
        const SizedBox(height: 10),
        InfoBanner(
          icon: Icons.call_split,
          title: 'Kết quả sau khi xác nhận',
          text: whole
              ? 'Lấy nguyên tem ${label.code} (${label.qty} thùng) mang đi.'
              : 'Tạo hai tem mới: tem giao $_qty thùng và tem thay thế ${label.qty - _qty} thùng cho hàng ở lại kệ. Tem ${label.code} giữ lịch sử ${label.qty} thùng và không dùng lại. In cả hai tem mới.',
        ),
        FilledButton(
            onPressed: _busy ? null : () => _confirm(line),
            child: Text(_busy ? 'Đang xử lý...' : 'Xác nhận số lượng')),
        TextButton(
            onPressed: () => setState(() => _label = null),
            child: const Text('Quét tem khác')),
      ],
    );
  }

  Widget _resultView(PickScanResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 10),
        InfoBanner(
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
          title: 'Đã lấy ${r.pickedQty} thùng',
          text: r.remainingLabel.isEmpty
              ? 'Tem mang đi: ${r.childLabel} (nguyên tem).'
              : 'Tem giao: ${r.childLabel} · ${r.pickedQty} thùng. Tem thay thế: ${r.remainingLabel} · ${r.remainingQty} thùng. Tem gốc ${r.sourceLabel} đã tách, không dùng lại.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                  'In tem chính thức từ máy chủ. Chọn máy in trong hộp thoại in.',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _printing ? null : () => _print(r.childLabel),
                icon: const Icon(Icons.print_outlined),
                label: Text('In tem giao ${r.childLabel}'),
              ),
              if (r.remainingLabel.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _printing ? null : () => _print(r.remainingLabel),
                  icon: const Icon(Icons.print_outlined),
                  label: Text('In tem thay thế ${r.remainingLabel}'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Về danh sách picking')),
      ],
    );
  }
}
