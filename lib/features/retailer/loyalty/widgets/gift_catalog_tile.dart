import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';

class GiftCatalogTile extends StatelessWidget {
  const GiftCatalogTile({super.key, required this.gift, required this.account,
    required this.busy, required this.onRedeem});
  final Gift gift;
  final LoyaltyAccount? account;
  final bool busy;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final enough = account != null && !account!.hasNegativeBalance && account!.balance >= gift.points;
    final available = gift.stock == null || gift.stock! > 0;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (gift.imageUrl?.isNotEmpty == true) ...[
        Image.network(gift.imageUrl!, height: 150, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(height: 70,
            child: Center(child: Text('Không tải được ảnh quà')))),
        const SizedBox(height: 10),
      ],
      Text(gift.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      Text(gift.code, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      if (gift.description?.isNotEmpty == true) ...[
        const SizedBox(height: 6), Text(gift.description!),
      ],
      const SizedBox(height: 8),
      Text('${gift.points} điểm / quà', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12, runSpacing: 8, children: [
        Text(gift.stock == null ? 'Không giới hạn số lượng' : 'Còn ${gift.stock} quà'),
        FilledButton(onPressed: !busy && available && enough ? onRedeem : null,
          child: Text(!available ? 'Hết quà' : !enough ? 'Thiếu điểm' : 'Đổi')),
      ]),
    ]));
  }
}
