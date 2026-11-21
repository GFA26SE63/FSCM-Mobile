import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Retailer card. With [onTap] it is a list row (storefront tile, name, code,
/// address, status/credit chips); without it, the detail header.
class RetailerSummaryCard extends StatelessWidget {
  const RetailerSummaryCard({
    super.key,
    required this.retailer,
    this.onTap,
  });

  final Retailer retailer;
  final VoidCallback? onTap;

  /// Colour of the status chip only; the label comes from the model.
  static StatusTone statusTone(String status) => switch (status) {
        'Active' => StatusTone.success,
        'PendingApproval' => StatusTone.warning,
        'Rejected' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.controlAll,
            ),
            child:
                const Icon(Icons.storefront_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(retailer.name, style: AppText.cardTitle),
                Text('Mã điểm bán: ${retailer.code}',
                    style: AppText.mutedSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  retailer.address.isEmpty
                      ? 'Chưa có địa chỉ'
                      : retailer.address,
                  maxLines: onTap == null ? null : 2,
                  overflow: onTap == null ? null : TextOverflow.ellipsis,
                  style: AppText.bodySmall.copyWith(color: AppColors.textLabel),
                ),
                const SizedBox(height: AppSpacing.s10),
                Wrap(
                  spacing: AppSpacing.s6,
                  runSpacing: AppSpacing.s6,
                  children: [
                    StatusChip(
                      label: retailer.statusLabel,
                      tone: statusTone(retailer.status),
                    ),
                    StatusChip(
                      label: retailer.creditAllowed
                          ? 'Kỳ hạn công nợ: ${retailer.creditTerm} ngày'
                          : 'Không mua công nợ',
                      tone: retailer.creditAllowed
                          ? StatusTone.info
                          : StatusTone.neutral,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
