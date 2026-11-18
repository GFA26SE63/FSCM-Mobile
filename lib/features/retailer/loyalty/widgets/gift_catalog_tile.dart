import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class GiftCatalogTile extends StatelessWidget {
  const GiftCatalogTile(
      {super.key,
      required this.gift,
      required this.account,
      required this.busy,
      required this.onRedeem});
  final Gift gift;
  final LoyaltyAccount? account;
  final bool busy;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final enough = account != null &&
        !account!.hasNegativeBalance &&
        account!.balance >= gift.points;
    final available = gift.stock == null || gift.stock! > 0;
    return AppCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 72,
            height: 72,
            child: gift.imageUrl?.isNotEmpty == true
                ? Image.network(gift.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Tooltip(
                        message: 'Không tải được ảnh quà',
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted, size: 32)))
                : const Icon(Icons.card_giftcard_outlined,
                    color: AppColors.primary, size: 36)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gift.name,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(gift.code,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (gift.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(gift.description!),
          ],
          const SizedBox(height: 6),
          Text('${gift.points} điểm / quà',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800)),
        ])),
      ]),
      const SizedBox(height: 10),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(gift.stock == null
                ? 'Không giới hạn số lượng'
                : 'Còn ${gift.stock} quà'),
            FilledButton(
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
