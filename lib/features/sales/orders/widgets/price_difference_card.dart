import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

class PriceDifferenceCard extends StatelessWidget {
  const PriceDifferenceCard({
    super.key,
    required this.localAmount,
    required this.serverAmount,
    this.title = 'Đối chiếu giá',
    this.serverLabel = 'Dự kiến từ máy chủ',
  });

  final num localAmount;
  final num serverAmount;
  final String title;
  final String serverLabel;

  @override
  Widget build(BuildContext context) {
    final difference = serverAmount - localAmount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          KvRow('Tạm tính trên máy', Money.format(localAmount)),
          KvRow(serverLabel, Money.format(serverAmount)),
          KvRow(
            'Chênh lệch',
            difference == 0
                ? 'Không thay đổi'
                : '${difference > 0 ? '+' : ''}'
                    '${Money.format(difference)}',
            bold: true,
          ),
          const SizedBox(height: 6),
          const Text(
            'Giá trước phân bổ chưa bao gồm kết quả giảm theo '
            'hạn sử dụng của batch được chọn.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
