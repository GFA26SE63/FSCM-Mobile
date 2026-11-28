import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class GiftCatalogTile extends StatelessWidget {
  const GiftCatalogTile(
      {super.key,
      required this.gift,
      required this.account,
      required this.busy,
      required this.onRedeem,
      this.programLabel});
  final Gift gift;
  final LoyaltyAccount? account;
  final bool busy;
  final VoidCallback? onRedeem;
  final String? programLabel;

  @override
  Widget build(BuildContext context) {
    final enough = account != null &&
        !account!.hasNegativeBalance &&
        account!.balance >= gift.points;
    final available = gift.stock == null || gift.stock! > 0;
    final missing = account == null ? 0 : gift.points - account!.balance;
    return AppCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Reward tile: image, or the prototype's amber gift tile.
        Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: gift.imageUrl?.isNotEmpty == true
                    ? AppColors.background
                    : AppColors.warningSoft,
                borderRadius: AppRadius.controlAll),
            clipBehavior: Clip.antiAlias,
            child: gift.imageUrl?.isNotEmpty == true
                ? Image.network(gift.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Tooltip(
                        message: 'Không tải được ảnh quà',
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted, size: 32)))
                : const Icon(Icons.card_giftcard_outlined,
                    color: AppColors.warning, size: 32)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gift.name, style: AppText.cardTitle),
          Text(gift.code, style: AppText.mutedSmall),
          if (programLabel != null)
            Text(programLabel!, style: AppText.mutedSmall),
          if (gift.description?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(gift.description!, style: AppText.bodySmall),
          ],
          const SizedBox(height: AppSpacing.s6),
          Text('${gift.points} điểm / quà',
              style: AppText.strong.copyWith(color: AppColors.warning)),
        ])),
      ]),
      const SizedBox(height: AppSpacing.s10),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      gift.stock == null
                          ? 'Không giới hạn số lượng'
                          : 'Còn ${gift.stock} quà',
                      style: AppText.mutedSmall),
                  // Insufficient-points state: how many points are missing.
                  if (available && !enough && missing > 0)
                    Text('Còn thiếu $missing điểm',
                        style: AppText.mutedSmall
                            .copyWith(color: AppColors.warning)),
                ]),
            FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(96, AppSizes.touch)),
                onPressed: !busy && available && enough ? onRedeem : null,
                child: Text(!available
                    ? 'Hết quà'
                    : !enough
                        ? 'Thiếu điểm'
                        : 'Đổi')),
          ]),
    ]));
  }
}
