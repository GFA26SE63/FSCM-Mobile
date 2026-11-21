import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_stock_summary.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen(
      {super.key,
      required this.product,
      required this.unitPrice,
      this.availability,
      this.viewerRole,
      this.promotions = const []});
  final Product product;
  final num? unitPrice;
  final ProductAvailability? availability;
  final UserRole? viewerRole;
  final List<Promotion> promotions;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(product.name, style: AppText.pageTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  unitPrice == null
                      ? 'Chưa có giá hiệu lực trong dữ liệu đồng bộ'
                      : '${Money.format(unitPrice!)} / ${product.pack} · dự kiến',
                  style: AppText.strong.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                KvRow('SKU', product.sku),
                KvRow('Danh mục', product.category),
                KvRow('Đơn vị', product.pack),
                KvRow('Hạn dùng', '${product.shelfLifeDays} ngày'),
              ])),
          if (promotions.isNotEmpty) ...[
            const SectionTitle('Khuyến mãi'),
            for (final promotion in promotions)
              AppCard(
                  color: AppColors.warningSoft,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(promotion.name,
                            style: AppText.strong
                                .copyWith(color: AppColors.warning)),
                        for (final condition in promotion.conditionLines)
                          Text(condition,
                              style: AppText.bodySmall
                                  .copyWith(color: AppColors.warning)),
                      ])),
          ],
          if (availability != null) ...[
            AppCard(
                child: OrderStockSummary(
                    availability: availability!,
                    viewerRole: viewerRole,
                    maxWarehouses: null)),
            const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text(
                    'Tồn được kiểm tra cho cửa hàng đang đặt đơn. Hệ thống tự chọn kho và lô hàng khi gửi đơn; số lượng có thể thay đổi.')),
          ] else
            const Text(
                'Kết nối mạng tại màn đặt hàng để kiểm tra tồn đáp ứng điều kiện giao cho cửa hàng.'),
        ]),
      );
}
