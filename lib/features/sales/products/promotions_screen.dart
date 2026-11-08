import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

import 'catalog_sync_button.dart';

class PromotionsScreen extends ConsumerStatefulWidget {
  const PromotionsScreen({super.key});

  @override
  ConsumerState<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends ConsumerState<PromotionsScreen> {
  String? _retailerCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khuyến mãi'),
        actions: const [CatalogSyncButton()],
      ),
      body: AsyncBody<CatalogData>(
        value: ref.watch(catalogProvider),
        onRetry: () => ref.invalidate(catalogProvider),
        builder: (data) {
          if (!data.hasSnapshot) {
            return const EmptyState(
              title: 'Chưa có khuyến mãi trên máy',
              message: 'Kết nối mạng và cập nhật catalog.',
            );
          }

          final retailerCodes =
              data.retailers.map((retailer) => retailer.code).toSet();

          final selectedCode =
              retailerCodes.contains(_retailerCode) ? _retailerCode : null;

          final promotions = data.runningPromotions(
            retailerCode: selectedCode,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InfoBanner(
                text: 'Snapshot ${AppDates.timeDay(data.lastSyncAt)}.\n'
                    'Mỗi dòng nhận tối đa một khuyến mãi đủ điều kiện. '
                    'Giá được backend kiểm tra lại khi gửi đơn.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(selectedCode ?? 'all'),
                initialValue: selectedCode ?? '',
                decoration: const InputDecoration(
                  labelText: 'Điểm bán áp dụng',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Tất cả chương trình trong snapshot'),
                  ),
                  for (final retailer in data.retailers)
                    DropdownMenuItem(
                      value: retailer.code,
                      child: Text(
                        '${retailer.code} · ${retailer.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _retailerCode =
                      value == null || value.isEmpty ? null : value,
                ),
                isExpanded: true,
              ),
              const SizedBox(height: 12),
              if (promotions.isEmpty)
                const EmptyState(
                  title: 'Không có khuyến mãi phù hợp đang chạy.',
                ),
              for (final promotion in promotions)
                AppCard(
                  child: Builder(
                    builder: (context) {
                      final record = data.promotionRecord(promotion) ?? {};

                      final productNames = promotion.groupSkus.map((sku) {
                        final product = data.product(sku);
                        return product == null ? sku : '$sku · ${product.name}';
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promotion.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final condition in promotion.conditionLines)
                            Text(condition),
                          const SizedBox(height: 6),
                          const Text(
                            'Sản phẩm trong phạm vi:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (productNames.isEmpty)
                            const Text(
                              'Không có SKU phù hợp trong catalog hiện tại.',
                            ),
                          for (final name in productNames) Text('• $name'),
                          const SizedBox(height: 8),
                          Text(
                            'Hiệu lực: '
                            '${AppDates.timeDay(promotion.validFrom)}'
                            ' → ${AppDates.timeDay(promotion.validTo)}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            promotion.retailerCodes == null
                                ? 'Áp dụng cho tất cả điểm bán.'
                                : 'Điểm bán được áp dụng trong scope: '
                                    '${promotion.retailerCodes!.join(', ')}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                          if (asStrList(record['categoryIds']).isNotEmpty)
                            const Text(
                              'Phạm vi gồm danh mục sản phẩm.',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
