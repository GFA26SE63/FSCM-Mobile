import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/focus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

import 'catalog_sync_button.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String _query = '';
  String _category = '';

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(networkMonitorProvider).online;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm'),
        actions: const [CatalogSyncButton()],
      ),
      body: AsyncBody<CatalogData>(
        value: ref.watch(catalogProvider),
        onRetry: () => ref.invalidate(catalogProvider),
        builder: (data) {
          if (!data.hasSnapshot) {
            return const EmptyState(
              icon: Icons.cloud_download_outlined,
              title: 'Chưa có danh mục sản phẩm trên máy',
              message: 'Kết nối mạng và bấm nút cập nhật ở góc trên.',
            );
          }

          final categories = data.products
              .map((product) => product.category)
              .toSet()
              .toList()
            ..sort();

          final selectedCategory =
              categories.contains(_category) ? _category : '';

          final products = data.products.where((product) {
            if (selectedCategory.isNotEmpty &&
                product.category != selectedCategory) {
              return false;
            }

            return _query.isEmpty ||
                product.name.toLowerCase().contains(_query) ||
                product.sku.toLowerCase().contains(_query);
          }).toList();

          return Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                          AppSpacing.md, AppSpacing.lg, AppSpacing.s10),
                      child: TextField(
                        onTapOutside: releaseFocus,
                        decoration: const InputDecoration(
                          hintText: 'Tìm sản phẩm hoặc SKU',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(
                          () => _query = value.trim().toLowerCase(),
                        ),
                      ),
                    ),
                    ChipFilterBar<String>(
                      options: [
                        const ChipOption<String>('', 'Tất cả'),
                        for (final category in categories)
                          ChipOption<String>(category, category),
                      ],
                      selected: selectedCategory,
                      onSelected: (value) => setState(
                        () => _category = value,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    InfoBanner(
                      text:
                          '${online ? 'Đang trực tuyến' : 'Đang dùng dữ liệu đã lưu'}'
                          ' · Dữ liệu đồng bộ ${AppDates.timeDay(data.lastSyncAt)}\n'
                          '${data.stockDisclaimer}\n'
                          '${data.priceDisclaimer}',
                    ),
                    if (products.isEmpty)
                      const EmptyState(
                        title: 'Không có sản phẩm phù hợp.',
                      ),
                    for (final product in products)
                      _tile(context, product, data),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    Product product,
    CatalogData data,
  ) {
    final price = data.displayPrice(product);
    final stock = data.displayStock(product);

    final promotions = data
        .runningPromotions()
        .where(
          (promotion) => promotion.groupSkus.contains(product.sku),
        )
        .toList();

    return AppCard(
      onTap: () => _showDetail(context, product, data),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category tile (prototype: 56px rounded tile with category).
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(AppSpacing.xs),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: AppRadius.controlAll,
                ),
                child: Text(
                  product.category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.caption
                      .copyWith(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: AppText.cardTitle),
                    Text('${product.sku} · ${product.pack}',
                        style: AppText.mutedSmall),
                    const SizedBox(height: AppSpacing.xs),
                    if (price == null)
                      const Text('Chưa có giá hiện hành trong dữ liệu đã lưu',
                          style: AppText.muted)
                    else
                      Text.rich(
                        TextSpan(
                          text: Money.format(price),
                          children: [
                            TextSpan(
                              text: ' / ${product.pack}',
                              style: AppText.mutedSmall,
                            ),
                          ],
                        ),
                        style:
                            AppText.strong.copyWith(color: AppColors.primary),
                      ),
                    Text(
                      stock == null
                          ? 'Chưa có số liệu tồn tham khảo'
                          : 'Tồn tham khảo: ${_quantity(stock)} thùng',
                      style: AppText.mutedSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (promotions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s10),
            for (final promotion in promotions)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.s6),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10, vertical: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: AppRadius.smallAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_offer_outlined,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        promotion.name,
                        style: AppText.bodySmall
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Khuyến mãi có thể áp dụng tùy điểm bán và số lượng.',
              style: AppText.mutedSmall,
            ),
          ],
        ],
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    Product product,
    CatalogData data,
  ) {
    final price = data.displayPrice(product);
    final stock = data.displayStock(product);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(product.name, style: AppText.pageTitle),
              const SizedBox(height: AppSpacing.md),
              KvRow('SKU', product.sku),
              KvRow('Danh mục', product.category),
              KvRow('Đơn vị', product.pack),
              KvRow(
                'Giá cơ sở dự kiến',
                price == null
                    ? 'Chưa có giá hiện hành trong dữ liệu đã lưu'
                    : Money.format(price),
              ),
              KvRow(
                'Tồn tham khảo',
                stock == null ? 'Chưa có số liệu' : '${_quantity(stock)} thùng',
              ),
              const SizedBox(height: AppSpacing.md),
              InfoBanner(
                text: '${data.stockDisclaimer}\n${data.priceDisclaimer}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _quantity(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
