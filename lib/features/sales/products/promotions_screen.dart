import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

/// "Khuyến mãi đang chạy" from the LocalPromotion cache.
class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khuyến mãi đang chạy')),
      body: AsyncBody<CatalogData>(
        value: ref.watch(catalogProvider),
        onRetry: () => ref.invalidate(catalogProvider),
        builder: (data) {
          final list = data.runningPromotions();
          if (list.isEmpty) {
            return const EmptyState(
                title: 'Hiện chưa có khuyến mãi nào đang chạy.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const InfoBanner(
                text:
                    'Mỗi dòng sản phẩm chỉ nhận 1 khuyến mãi; nếu đạt nhiều chương trình, hệ thống chọn chương trình giảm nhiều nhất.',
              ),
              for (final p in list)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${p.id} · ${p.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(p.typeLabel,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      const Text('Điều kiện',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      for (final c in p.conditionLines) Text('• $c'),
                      const SizedBox(height: 6),
                      Text('Hiệu lực: ${p.validText}'),
                      Text(
                        p.retailerCodes == null
                            ? 'Điểm bán áp dụng: tất cả'
                            : 'Điểm bán áp dụng: ${p.retailerCodes!.length} điểm bán (${p.retailerCodes!.join(', ')})',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
