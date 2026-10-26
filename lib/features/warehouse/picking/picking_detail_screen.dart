import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/quantity.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/run_picking.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// F43: one warehouse's picking sheet for a run.
///
/// Gather first, split second, because that is the order the work happens in:
/// one trip to a batch collects everything the run needs from it, and the split
/// rows underneath say which order each carton belongs to.
///
/// Two things this screen does not do. It never merges two batches of one SKU
/// into a single row - the batch is what the allocation and its price were
/// decided on, and a keeper picking off a different pallet would quietly break
/// the trace. And it never shows or computes money: each split carries the id
/// of the price record the run approved, and that reference is all a picking
/// sheet needs. Changing the price here is not a thing the screen can do.
class PickingDetailScreen extends ConsumerWidget {
  const PickingDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(pickingDetailProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text(code)),
      body: AsyncBody<RunPickingSheet>(
        value: value,
        onRetry: () => ref.invalidate(pickingDetailProvider(code)),
        builder: (sheet) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pickingDetailProvider(code)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _Header(sheet: sheet),
              const SectionTitle('Lấy gom theo batch'),
              for (final gather in sheet.gathers)
                _GatherCard(sheet: sheet, gather: gather),
              const SectionTitle('Xuất kho theo đơn'),
              const InfoBanner(
                icon: Icons.info_outline,
                text:
                    'Soạn xong chưa phải là xuất. Mỗi đơn chỉ được xuất khi mọi phần hàng theo kho của nó đã soạn đủ và đạt điều kiện thanh toán — máy chủ quyết định, không phải phiếu này.',
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

class _Header extends StatelessWidget {
  const _Header({required this.sheet});

  final RunPickingSheet sheet;

  @override
  Widget build(BuildContext context) {
    final s = sheet;
    final progress =
        s.totalRequired == 0 ? 0.0 : s.totalPicked / s.totalRequired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
                child: Text('${s.gathers.length} lượt lấy · '
                    '${s.orderCodes.length} đơn')),
            StatusChip(label: s.status.label, tone: s.status.tone),
          ],
        ),
        Text('Phát hành ${AppDates.timeDay(s.issuedAt)}',
            style: const TextStyle(color: AppColors.textMuted)),
        if (s.completedAt != null)
          Text('Soạn xong ${AppDates.timeDay(s.completedAt)}',
              style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Text(
            'Tiến độ: ${s.doneGathers}/${s.gathers.length} lượt · '
            '${Qty.format(s.totalPicked)}/${Qty.cartons(s.totalRequired)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        if (s.hasException) ...<Widget>[
          const SizedBox(height: 10),
          InfoBanner(
            tone: StatusTone.danger,
            icon: Icons.error_outline,
            title: 'Ngoại lệ: ${s.exceptionType}',
            text:
                '${s.exceptionNote ?? 'Chưa có ghi chú.'} Một kho có ngoại lệ thì cả đơn phải được xử lý trước khi bất kỳ phần nào được xuất.',
          ),
        ],
      ],
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
                  child: Text(g.sku,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              StatusChip(label: g.status.label, tone: g.status.tone),
            ],
          ),
          // The batch stays on screen and is not selectable: it is what the
          // allocation and its approved price were decided on.
          Text('Batch ${g.batchCode}',
              style: const TextStyle(color: AppColors.textMuted)),
          Text(
              'Cần lấy ${Qty.cartons(g.requiredQuantity)} · '
              'đã lấy ${Qty.format(g.pickedQuantity)} · '
              'còn ${Qty.format(g.remainingQuantity)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Chia về đơn',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          for (final split in g.splits)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                      child: Text(split.orderCode,
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                      '${Qty.format(split.pickedQuantity)}/${Qty.cartons(split.requiredQuantity)}'),
                  if (split.isDone)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle,
                          size: 16, color: AppColors.success),
                    ),
                ],
              ),
            ),
          if (!sheet.isClosed && !g.isDone) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push(AppRoutes.wkPickGather(sheet.pickingCode, g.id)),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét tem nguồn'),
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
