import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/chip_filter_bar.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

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
              title: 'Chưa có catalog trên máy',
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    InfoBanner(
                      text:
                          '${online ? 'Đang online' : 'Đang dùng cache offline'}'
                          ' · Snapshot ${AppDates.timeDay(data.lastSyncAt)}\n'
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
          Text(
            '${product.sku} · ${product.name}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${product.pack} · ${product.category}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            price == null
                ? 'Chưa có giá hiện hành trong cache'
                : '${Money.format(price)} / ${product.pack}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(
            stock == null
                ? 'Chưa có số liệu tồn tham khảo'
                : 'Tồn tham khảo: ${_quantity(stock)} thùng',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (promotions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final promotion in promotions)
                  Chip(
                    label: Text(promotion.name),
                  ),
              ],
            ),
            const Text(
              'Khuyến mãi có thể áp dụng tùy điểm bán và số lượng.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('SKU: ${product.sku}'),
              Text('Danh mục: ${product.category}'),
              Text('Đơn vị: ${product.pack}'),
              Text(
                price == null
                    ? 'Giá: chưa có giá hiện hành trong cache'
                    : 'Giá cơ sở dự kiến: ${Money.format(price)}',
              ),
              Text(
                stock == null
                    ? 'Tồn: chưa có số liệu'
                    : 'Tồn tham khảo: ${_quantity(stock)} thùng',
              ),
              const SizedBox(height: 12),
              Text(data.stockDisclaimer),
              const SizedBox(height: 8),
              Text(data.priceDisclaimer),
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
