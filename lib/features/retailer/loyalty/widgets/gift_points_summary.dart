import 'package:flutter/material.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
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
              const Text('Điểm khả dụng',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${account.balance}',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: account.hasNegativeBalance
                            ? AppColors.danger
                            : AppColors.primary)),
              ),
              const Text('điểm', style: TextStyle(color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF3E2),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Đang giữ đổi quà',
                        style: TextStyle(color: Color(0xFF8A3B09))),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${account.held}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF8A3B09))),
                    ),
                    const Text('điểm',
                        style: TextStyle(color: Color(0xFF8A3B09))),
                  ]),
            ),
          ),
        ]),
      );
}
