import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';

/// Label lookup: batch, quantity, location, parent/children and history.
class LabelDetailScreen extends ConsumerWidget {
  const LabelDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(labelProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text('Tem $code')),
      body: AsyncBody<LabelInfo>(
        value: value,
        onRetry: () => ref.invalidate(labelProvider(code)),
        builder: (l) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.qr_code_2,
                          size: 40, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                      StatusChip(label: l.status.label, tone: l.status.tone),
                    ],
                  ),
                  const SizedBox(height: 8),
                  KvRow('Sản phẩm', '${l.sku} · ${l.name}'),
                  KvRow('Batch', l.batchCode),
                  KvRow('Hạn sử dụng', AppDates.date(l.expiry)),
                  KvRow('Số lượng', '${l.qty} thùng', bold: true),
                  if (l.warehouseName.isNotEmpty) KvRow('Kho', l.warehouseName),
                  if (l.location.isNotEmpty) KvRow('Vị trí', l.location),
                  if (l.pickingCode.isNotEmpty)
                    KvRow('Phiếu picking', l.pickingCode),
                  if (l.orderCode.isNotEmpty) KvRow('Đơn hàng', l.orderCode),
                ],
              ),
            ),
            if (l.parentCode.isNotEmpty) ...<Widget>[
              const SectionTitle('Tem gốc'),
              _labelLink(context, l.parentCode),
            ],
            if (l.children.isNotEmpty) ...<Widget>[
              const SectionTitle('Tem con đã tách'),
              for (final c in l.children) _labelLink(context, c),
            ],
            if (l.history.isNotEmpty) ...<Widget>[
              const SectionTitle('Lịch sử tem'),
              AppCard(child: TimelineList(l.history)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _labelLink(BuildContext context, String code) => AppCard(
        onTap: () => context.push(AppRoutes.wkLabel(code)),
        child: Row(
          children: <Widget>[
            const Icon(Icons.label_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(code,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      );
}
