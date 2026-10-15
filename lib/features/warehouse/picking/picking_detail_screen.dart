import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// One picking list: lines to pick (FEFO-suggested label), progress and the
/// "Xác nhận đã xuất" action.
class PickingDetailScreen extends ConsumerWidget {
  const PickingDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(pickingDetailProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text(code)),
      body: AsyncBody<PickingList>(
        value: value,
        onRetry: () => ref.invalidate(pickingDetailProvider(code)),
        builder: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: Text(p.retailerName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800))),
                StatusChip(label: p.status.label, tone: p.status.tone),
              ],
            ),
            Text('Đơn ${p.orderCode} · ${p.warehouseName}',
                style: const TextStyle(color: AppColors.textMuted)),
            if (p.siblingText.isNotEmpty)
              Text('Cùng đơn: ${p.siblingText}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 12),
            Text(
                'Tiến độ: ${p.doneLines}/${p.lines.length} dòng · ${p.totalPicked}/${p.totalNeed} thùng',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: p.lines.isEmpty ? 0 : p.doneLines / p.lines.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 14),
            for (final l in p.lines) _LineCard(list: p, line: l),
            const SizedBox(height: 6),
            if (p.isShipped)
              InfoBanner(
                icon: Icons.check_circle_outline,
                text:
                    'Đã xuất kho lúc ${AppDates.timeDay(p.shippedAt)}. Các tem chuyển "Đang vận chuyển" - retailer sẽ quét khi nhận hàng.',
              )
            else ...<Widget>[
              FilledButton.icon(
                onPressed: p.allDone ? () => _ship(context, ref, p) : null,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Xác nhận đã xuất'),
              ),
              const SizedBox(height: 6),
              Text(
                p.allDone
                    ? 'Tồn thực tế sẽ bị trừ, tem chuyển Đang vận chuyển.'
                    : 'Quét đủ tất cả dòng để xác nhận xuất.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _ship(BuildContext context, WidgetRef ref, PickingList p) async {
    final ok = await confirmDialog(
      context,
      title: 'Xác nhận xuất kho ${p.code}?',
      message:
          'Tồn thực tế đã trừ, hàng Reserved được giải phóng. Các tem chuyển Đang vận chuyển.',
      confirmLabel: 'Xuất kho',
    );
    if (!ok) return;
    try {
      await ref.read(warehouseRepositoryProvider).ship(p.code);
      ref.invalidate(pickingDetailProvider(p.code));
      ref.read(dataVersionProvider.notifier).state++;
      if (context.mounted) showAppSnack(context, 'Đã xuất kho ${p.code}.');
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.list, required this.line});

  final PickingList list;
  final PickingLine line;

  @override
  Widget build(BuildContext context) {
    final l = line;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Text('${l.sku} · ${l.name}',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              if (l.isDone)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 4),
          Text('Batch ${l.batchCode}',
              style: const TextStyle(color: AppColors.textMuted)),
          Text('HSD ${AppDates.date(l.expiry)} · Vị trí ${l.location}'),
          Text('Cần lấy: ${l.need} thùng (đã lấy ${l.picked})',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Tem gợi ý (FEFO): ${l.suggestedLabel}',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
          if (l.outLabel.isNotEmpty) Text('Tem mang đi: ${l.outLabel}'),
          if (!list.isShipped && !l.isDone) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push(AppRoutes.wkPickLine(list.code, l.index)),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét tem nguồn'),
            ),
          ],
        ],
      ),
    );
  }
}
