import 'package:flutter/material.dart';

import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class RetailerSummaryCard extends StatelessWidget {
  const RetailerSummaryCard({
    super.key,
    required this.retailer,
    this.onTap,
  });

  final Retailer retailer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  retailer.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Mã điểm bán: ${retailer.code}'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  retailer.address.isEmpty
                      ? 'Chưa có địa chỉ'
                      : retailer.address,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Trạng thái: ${retailer.statusLabel}'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  retailer.creditAllowed
                      ? 'Kỳ hạn công nợ: ${retailer.creditTerm} ngày'
                      : 'Không mua công nợ',
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
