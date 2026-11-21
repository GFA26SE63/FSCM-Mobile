import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class GiftPointsSummary extends StatelessWidget {
  const GiftPointsSummary({super.key, required this.account});

  final LoyaltyAccount account;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Điểm khả dụng', style: AppText.muted),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${account.balance}',
                    style: AppText.display.copyWith(
                        fontSize: 32,
                        color: account.hasNegativeBalance
                            ? AppColors.danger
                            : AppColors.primary)),
              ),
              const Text('điểm', style: AppText.muted),
            ]),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: AppRadius.controlAll),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đang giữ đổi quà',
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.warning)),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${account.held}',
                          style: AppText.display.copyWith(
                              fontSize: 22, color: AppColors.warning)),
                    ),
                    Text('điểm',
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.warning)),
                  ]),
            ),
          ),
        ]),
      );
}
