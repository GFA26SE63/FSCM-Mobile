import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/label_detail.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

class LabelDetailContent extends StatelessWidget {
  const LabelDetailContent({
    super.key,
    required this.detail,
  });

  final LabelDetail detail;

  @override
  Widget build(BuildContext context) {
    final label = detail.label;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(label.code,
                      style: AppText.display.copyWith(color: AppColors.text)),
                  StatusChip(
                    label: label.status.label,
                    tone: label.status.tone,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              KvRow('Sản phẩm', '${label.sku} · ${label.name}'),
              KvRow('Lô hàng', label.batchCode),
              KvRow('Kho', label.warehouseName),
              KvRow('Số lượng', '${label.qty} thùng', bold: true),
              KvRow('Hạn sử dụng', AppDates.date(label.expiry)),
              if (label.status == LabelStatus.invalidated)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: InfoBanner(
                    tone: StatusTone.danger,
                    icon: Icons.block,
                    text:
                        'Tem đã bị vô hiệu hóa. Không sử dụng tem này để lấy hàng.',
                  ),
                ),
            ],
          ),
        ),
        if (detail.rootCode.isNotEmpty && detail.rootCode != label.code) ...[
          const SectionTitle('Tem gốc'),
          _codeLink(context, detail.rootCode),
        ],
        if (label.parentCode.isNotEmpty &&
            label.parentCode != detail.rootCode) ...[
          const SectionTitle('Tem cha trực tiếp'),
          _codeLink(context, label.parentCode),
        ],
        const SectionTitle('Tem con trực tiếp'),
        if (detail.children.isEmpty)
          const AppCard(
            child: Text('Không có tem con trực tiếp.'),
          )
        else
          for (final child in detail.children) _labelLink(context, child),
        const SectionTitle('Lịch sử chuỗi tem'),
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Lịch sử do máy chủ trả về cho chuỗi tem gốc và các tem con.',
            style: AppText.mutedSmall,
          ),
        ),
        if (detail.events.isEmpty)
          const AppCard(
            child: Text('Chưa có lịch sử tem.'),
          )
        else
          for (final event in detail.events)
            AppCard(
              key: ValueKey(event.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: AppText.strong),
                  Text(AppDates.timeDay(event.occurredAt?.toLocal()),
                      style: AppText.mutedSmall),
                  const SizedBox(height: AppSpacing.xs),
                  if (event.warehouseCode.isNotEmpty)
                    KvRow('Kho', event.warehouseCode),
                  KvRow(
                    'Số lượng',
                    '${_quantity(event.quantity)} thùng',
                  ),
                  if (event.fromStatus.isNotEmpty)
                    KvRow('Từ trạng thái', _status(event.fromStatus)),
                  if (event.toStatus.isNotEmpty)
                    KvRow('Đến trạng thái', _status(event.toStatus)),
                  if (event.referenceCode.isNotEmpty)
                    KvRow('Tham chiếu', event.referenceCode),
                  if (event.note.isNotEmpty) KvRow('Ghi chú', event.note),
                ],
              ),
            ),
      ],
    );
  }

  Widget _codeLink(BuildContext context, String code) {
    return AppCard(
      onTap: () => context.push(AppRoutes.wkLabel(code)),
      child: Row(
        children: [
          Expanded(child: Text(code, style: AppText.strong)),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _labelLink(BuildContext context, LabelInfo label) {
    return AppCard(
      onTap: () => context.push(AppRoutes.wkLabel(label.code)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.code, style: AppText.strong),
                Text('${label.qty} thùng · ${label.status.label}',
                    style: AppText.mutedSmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }

  String _status(String raw) {
    final status = LabelStatus.fromCode(raw);
    return status == LabelStatus.unknown ? raw : status.label;
  }

  String _quantity(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
