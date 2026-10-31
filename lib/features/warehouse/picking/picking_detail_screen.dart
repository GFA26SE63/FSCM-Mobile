import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Picking detail screen matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.warehouse` PICKING DETAIL).
class PickingDetailScreen extends ConsumerWidget {
  const PickingDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(pickingDetailProvider(code));
    return AsyncBody<PickingList>(
      value: value,
      onRetry: () => ref.invalidate(pickingDetailProvider(code)),
      builder: (p) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Phần giao ${p.code}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                'Thuộc đơn ${p.orderCode} · ${p.retailerName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AppCard(
              child: Column(
                children: <Widget>[
                  KvRow(
                    'Điểm bán nhận',
                    '${p.retailerName} (${p.retailerCode})',
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Trạng thái',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      StatusChip(label: p.status.label, tone: p.status.tone),
                    ],
                  ),
                  if (p.siblingText.isNotEmpty)
                    KvRow('Cùng đơn ${p.orderCode}', p.siblingText),
                  KvRow(
                      'Tiến độ soạn', '${p.doneLines}/${p.lines.length} dòng'),
                ],
              ),
            ),
            const SectionTitle('Danh sách dòng cần soạn (ưu tiên FEFO)'),
            for (final l in p.lines) _LineCard(list: p, line: l),
            if (!p.isShipped) ...<Widget>[
              OutlinedButton.icon(
                onPressed: () => _showExceptionSheet(context, p),
                icon: const Icon(Icons.error_outline, size: 18),
                label: const Text('Báo ngoại lệ (thiếu / hư hỏng / sai tem)'),
              ),
              const SizedBox(height: 10),
            ],
            if (p.isShipped)
              InfoBanner(
                icon: Icons.check_circle_outline,
                text:
                    'Đã xuất kho lúc ${AppDates.timeDay(p.shippedAt)}. Tồn kho đã trừ, các tem mang đi chuyển trạng thái Đang vận chuyển.',
              )
            else ...<Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: p.allDone ? () => _ship(context, ref, p) : null,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Xác nhận xuất phần giao'),
              ),
              const SizedBox(height: 6),
              Text(
                p.allDone
                    ? 'Tồn thực tế sẽ bị trừ, tem chuyển Đang vận chuyển.'
                    : 'Quét đủ tất cả dòng để xác nhận xuất.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                ),
              ),
              for (final orderCode in sheet.orderCodes)
                _OrderRow(sheet: sheet, orderCode: orderCode),
              const SizedBox(height: 10),
              _CloseSection(sheet: sheet),
            ],
          ),
        ),
      ),
    );
  }
}

  Future<void> _showExceptionSheet(BuildContext context, PickingList p) async {
    const reasons = <String>[
      'Không tìm thấy tem nguồn tại vị trí kệ',
      'Hàng tại vị trí bị rách / móp / ẩm',
      'Số lượng thực tế trên tem ít hơn hệ thống',
      'Tem bị mờ không quét được QR',
    ];
    String selected = reasons.first;
    final noteCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5D1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Báo ngoại lệ · Phần giao ${p.code}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gửi thông báo tới Operator điều phối để cấp lại lô / vị trí thay thế.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Loại ngoại lệ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final r in reasons)
                        ChoiceChip(
                          label: Text(r, style: const TextStyle(fontSize: 12)),
                          selected: selected == r,
                          onSelected: (_) => setSheetState(() => selected = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ghi chú chi tiết',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Vị trí kệ, mã tem, tình trạng thực tế...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            showAppSnack(
                              context,
                              'Đã gửi báo cáo ngoại lệ cho Operator.',
                            );
                          },
                          child: const Text('Gửi báo cáo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _ship(BuildContext context, WidgetRef ref, PickingList p) async {
    final ok = await confirmDialog(
      context,
      title: 'Xác nhận xuất phần giao ${p.code}?',
      message:
          'Tồn thực tế đã trừ, hàng Reserved được giải phóng. Các tem chuyển Đang vận chuyển.',
      confirmLabel: 'Xuất kho',
    );
  }
}

class _GatherCard extends StatelessWidget {
  const _GatherCard({required this.sheet, required this.gather});

  final RunPickingSheet sheet;
  final RunPickingGather gather;

  @override
  Widget build(BuildContext context) {
    final g = gather;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${l.index + 1}. ${l.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${l.sku} · Đã lấy ${l.picked}/${l.need}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: l.isDone ? 'Đã soạn' : 'Cần lấy ${l.need} thùng',
                tone: l.isDone ? StatusTone.success : StatusTone.info,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Gợi ý FEFO: Lô ${l.batchCode} · HSD ${AppDates.date(l.expiry)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vị trí ${l.location} · Tem nguồn ${l.suggestedLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (l.outLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Tem mang đi: ${l.outLabel}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
          if (!list.isShipped && !l.isDone) ...<Widget>[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () =>
                  context.push(AppRoutes.wkPickLine(list.code, l.index)),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Quét soạn dòng này'),
            ),
          ],
        ],
      ),
    );
  }
}

/// One order on this sheet, as a door into the readiness and issue screen.
///
/// Deliberately says nothing about whether the order may leave. That verdict
/// covers warehouses this sheet knows nothing about, so guessing it from the
/// splits here would be wrong about half the time; it is fetched where it is
/// shown.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.sheet, required this.orderCode});

  final RunPickingSheet sheet;
  final String orderCode;

  @override
  Widget build(BuildContext context) {
    final parts = sheet.partsOf(orderCode);
    final required =
        parts.fold<double>(0, (s, p) => s + p.split.requiredQuantity);
    final picked = parts.fold<double>(0, (s, p) => s + p.split.pickedQuantity);
    final batches = parts.map((p) => p.gather.batchCode).toSet();
    return AppCard(
      onTap: () =>
          context.push(AppRoutes.wkOrderIssue(sheet.pickingCode, orderCode)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(orderCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                    'Phần kho này: ${Qty.format(picked)}/${Qty.cartons(required)} · '
                    '${batches.length} batch',
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _CloseSection extends ConsumerWidget {
  const _CloseSection({required this.sheet});

  final RunPickingSheet sheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = sheet;
    if (s.isClosed) {
      return InfoBanner(
        tone: s.hasException ? StatusTone.danger : StatusTone.primary,
        icon:
            s.hasException ? Icons.report_outlined : Icons.inventory_2_outlined,
        text: s.hasException
            ? 'Phiếu đã đóng với ngoại lệ. Người có quyền phải xử lý trước khi đơn được xuất.'
            : 'Phiếu đã soạn xong lúc ${AppDates.timeDay(s.completedAt)}. Hàng chưa rời kho và tồn chưa thay đổi — mở từng đơn ở trên để xác nhận xuất.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: s.allPicked ? () => _complete(context, ref, s) : null,
          icon: const Icon(Icons.playlist_add_check),
          label: const Text('Đóng phiếu soạn'),
        ),
        const SizedBox(height: 6),
        Text(
          s.allPicked
              ? 'Đóng phiếu là xong bước soạn. Tồn chưa bị trừ, hàng chưa rời kho.'
              : 'Quét đủ mọi lượt lấy để đóng phiếu.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _flagException(context, ref, s),
          icon: const Icon(Icons.report_outlined),
          label: const Text('Báo ngoại lệ (thiếu/hỏng)'),
        ),
      ],
    );
  }

  Future<void> _complete(
      BuildContext context, WidgetRef ref, RunPickingSheet s) async {
    final ok = await confirmDialog(
      context,
      title: 'Đóng phiếu ${s.pickingCode}?',
      message:
          'Xác nhận đã lấy đủ mọi lượt. Đây là xong bước soạn — tồn chưa bị trừ và hàng chưa rời kho.',
      confirmLabel: 'Đóng phiếu',
    );
    if (!ok) return;
    if (!context.mounted) return;
    await _send(context, ref, s, null, null);
  }

  Future<void> _flagException(
      BuildContext context, WidgetRef ref, RunPickingSheet s) async {
    final choice = await showModalBottomSheet<({String type, String note})>(
      context: context,
      builder: (ctx) => const _ExceptionSheet(),
    );
    if (choice == null) return;
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Báo ngoại lệ cho ${s.pickingCode}?',
      message:
          'Cả đơn sẽ chuyển Cần xử lý và mọi phần chưa xuất bị chặn, kể cả phần ở kho khác. Không có chuyện giao một phần.',
      confirmLabel: 'Báo ngoại lệ',
    );
    if (!ok) return;
    if (!context.mounted) return;
    await _send(context, ref, s, choice.type, choice.note);
  }

  Future<void> _send(BuildContext context, WidgetRef ref, RunPickingSheet s,
      String? exceptionType, String? note) async {
    try {
      await ref.read(warehouseRepositoryProvider).completeSheet(
            s.pickingCode,
            expectedPickingVersion: s.version,
            exceptionType: exceptionType,
            note: note,
          );
      ref.invalidate(pickingDetailProvider(s.pickingCode));
      ref.read(dataVersionProvider.notifier).state++;
      if (context.mounted) {
        showAppSnack(
            context,
            exceptionType == null
                ? 'Đã đóng phiếu ${s.pickingCode}.'
                : 'Đã báo ngoại lệ cho ${s.pickingCode}.');
      }
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

class _ExceptionSheet extends StatefulWidget {
  const _ExceptionSheet();

  @override
  State<_ExceptionSheet> createState() => _ExceptionSheetState();
}

class _ExceptionSheetState extends State<_ExceptionSheet> {
  String _type = 'Shortage';
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('Loại ngoại lệ',
              style: TextStyle(fontWeight: FontWeight.w800)),
          RadioListTile<String>(
            value: 'Shortage',
            groupValue: _type,
            onChanged: (v) => setState(() => _type = v ?? _type),
            title: const Text('Thiếu hàng trên kệ'),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            value: 'Damaged',
            groupValue: _type,
            onChanged: (v) => setState(() => _type = v ?? _type),
            title: const Text('Hàng hỏng'),
            contentPadding: EdgeInsets.zero,
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Ghi chú', hintText: 'Mô tả ngắn cho người xử lý'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop((type: _type, note: _note.text.trim())),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }
}
