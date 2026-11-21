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
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// One picking list: lines to pick (FEFO-suggested label), progress and the
/// "Hoàn tất soạn" action. Shipment issue and dispatch are separate steps.
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            // Header card: retailer + status, order/warehouse, overall progress.
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      Text(p.retailerName,
                          style: AppText.pageTitle
                              .copyWith(color: AppColors.text)),
                      StatusChip(label: p.status.label, tone: p.status.tone),
                    ],
                  ),
                  Text('Đơn ${p.orderCode} · ${p.warehouseName}',
                      style: AppText.muted),
                  if (p.siblingText.isNotEmpty)
                    Text('Cùng đơn: ${p.siblingText}',
                        style: AppText.mutedSmall),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                      'Tiến độ: ${p.doneLines}/${p.lines.length} dòng · ${p.totalPicked}/${p.totalNeed} thùng',
                      style: AppText.cardTitle),
                  const SizedBox(height: AppSpacing.s6),
                  ClipRRect(
                    borderRadius: AppRadius.pillAll,
                    child: LinearProgressIndicator(
                      value: p.lines.isEmpty ? 0 : p.doneLines / p.lines.length,
                      minHeight: 8,
                      backgroundColor: AppColors.primarySoft,
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('Các dòng cần lấy'),
            for (final l in p.lines) _LineCard(list: p, line: l),
            const SizedBox(height: AppSpacing.s6),
            if (p.isCompleted)
              InfoBanner(
                icon: Icons.check_circle_outline,
                text:
                    'Đã soạn xong lúc ${AppDates.timeDay(p.shippedAt)}. Portal sẽ tạo phiếu giao hàng để xác nhận xuất kho và điều phối giao.',
              )
            else ...<Widget>[
              FilledButton.icon(
                onPressed: p.allDone ? () => _complete(context, ref, p) : null,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Hoàn tất soạn hàng'),
              ),
              const SizedBox(height: AppSpacing.s6),
              Text(
                p.allDone
                    ? 'Bước này chỉ đóng phiếu soạn; tồn thực tế chỉ trừ khi phiếu giao hàng được xác nhận xuất.'
                    : 'Quét đủ tất cả dòng để hoàn tất phiếu soạn.',
                textAlign: TextAlign.center,
                style: AppText.mutedSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _complete(
      BuildContext context, WidgetRef ref, PickingList p) async {
    final ok = await confirmDialog(
      context,
      title: 'Hoàn tất soạn hàng ${p.code}?',
      message:
          'Hệ thống sẽ đóng phiếu soạn và tạo phiếu giao hàng sẵn sàng xuất. Tồn chưa bị trừ ở bước này.',
      confirmLabel: 'Hoàn tất',
    );
    if (!ok) return;
    try {
      await ref.read(warehouseRepositoryProvider).complete(p.code, p.version);
      ref.invalidate(pickingDetailProvider(p.code));
      ref.read(dataVersionProvider.notifier).state++;
      if (context.mounted) showAppSnack(context, 'Đã hoàn tất soạn ${p.code}.');
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
                  child: Text('${l.sku} · ${l.name}', style: AppText.strong)),
              if (l.isDone)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Lô hàng ${l.batchCode}', style: AppText.muted),
          Text(
              'HSD ${AppDates.date(l.expiry)}${l.location.isEmpty ? '' : ' · Vị trí ${l.location}'}'),
          Text('Cần lấy: ${l.need} thùng (đã lấy ${l.picked})',
              style: AppText.strong),
          if (l.suggestedLabel.isNotEmpty)
            Text('Tem gợi ý (ưu tiên hết hạn trước): ${l.suggestedLabel}',
                style: AppText.cardTitle
                    .copyWith(fontSize: 14, color: AppColors.primary)),
          if (l.outLabel.isNotEmpty) Text('Tem mang đi: ${l.outLabel}'),
          if (!list.isCompleted && !l.isDone) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
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
