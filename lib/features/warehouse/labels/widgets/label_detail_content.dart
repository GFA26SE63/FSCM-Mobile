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
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.code,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              StatusChip(
                label: label.status.label,
                tone: label.status.tone,
              ),
              const SizedBox(height: 12),
              KvRow('Sản phẩm', '${label.sku} · ${label.name}'),
              KvRow('Batch', label.batchCode),
              KvRow('Kho', label.warehouseName),
              KvRow('Số lượng', '${label.qty} thùng', bold: true),
              KvRow('Hạn sử dụng', AppDates.date(label.expiry)),
              if (label.status == LabelStatus.invalidated)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
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
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Lịch sử do backend trả về cho chuỗi tem gốc và các tem con.',
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
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(AppDates.timeDay(event.occurredAt?.toLocal())),
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
          Expanded(child: Text(code)),
          const Icon(Icons.chevron_right),
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
                Text(label.code),
                Text('${label.qty} thùng · ${label.status.label}'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
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
