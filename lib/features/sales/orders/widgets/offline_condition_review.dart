import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/offline_condition_conflict.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/price_difference_card.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

class OfflineConditionReview extends StatelessWidget {
  const OfflineConditionReview({super.key, required this.conflict});

  final OfflineConditionConflict conflict;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PriceDifferenceCard(
            localAmount: conflict.offlineEstimatedAmount,
            serverAmount: conflict.currentIndicativeAmount,
            title: 'Điều kiện cần xác nhận',
            serverLabel: 'Dự kiến máy chủ trả về',
          ),
          for (final line in conflict.changedLines)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.sku,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (line.expectedBaseUnitPrice != line.currentBaseUnitPrice)
                    KvRow(
                        'Đơn giá dự kiến',
                        '${Money.format(line.expectedBaseUnitPrice)} → '
                            '${Money.format(line.currentBaseUnitPrice)}'),
                  if (line.expectedMlorRatio != line.currentMlorRatio)
                    KvRow(
                        'HSD tối thiểu (MLOR)',
                        '${(line.expectedMlorRatio * 100).toStringAsFixed(2)}% → '
                            '${(line.currentMlorRatio * 100).toStringAsFixed(2)}%'),
                  if (line.expectedMlorVersion != line.currentMlorVersion)
                    KvRow('Phiên bản MLOR',
                        '${line.expectedMlorVersion} → ${line.currentMlorVersion}'),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Giữ nguyên bản tạm tính gốc để đối chiếu. '
                'Chỉ tiếp tục gửi nếu bạn đồng ý với điều kiện máy chủ trả về.'),
          ),
        ],
      );
}

class OfflineConditionReviewSheet extends StatelessWidget {
  const OfflineConditionReviewSheet({
    super.key,
    required this.localCode,
    required this.conflict,
  });

  final String localCode;
  final OfflineConditionConflict conflict;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              Text('Đối chiếu $localCode',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              OfflineConditionReview(conflict: conflict),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Đồng ý điều kiện mới và gửi'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Để sau, giữ draft trên máy'),
              ),
            ],
          ),
        ),
      );
}
