import 'package:flutter/material.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/order_availability.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/warehouse_stock_list.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen(
      {super.key,
      required this.product,
      required this.unitPrice,
      this.availability,
      this.promotions = const []});
  final Product product;
  final num? unitPrice;
  final ProductAvailability? availability;
  final List<Promotion> promotions;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(product.name,
                    style: Theme.of(context).textTheme.titleLarge),
                Text('SKU: ${product.sku}'),
                Text('Danh mục: ${product.category}'),
                Text('Đơn vị: ${product.pack}'),
                Text('Hạn dùng: ${product.shelfLifeDays} ngày'),
                Text(unitPrice == null
                    ? 'Chưa có giá hiệu lực trong snapshot'
                    : '${Money.format(unitPrice!)} / ${product.pack} · dự kiến'),
              ])),
          if (availability != null) ...[
            AppCard(
                child: WarehouseStockList(
                    warehouses: availability!.warehouses, maxItems: null)),
            const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                    'Tồn được kiểm tra cho cửa hàng đang đặt đơn. Hệ thống tự chọn kho và batch khi gửi đơn; số lượng có thể thay đổi.')),
          ] else
            const Text(
                'Kết nối mạng tại màn đặt hàng để kiểm tra tồn đáp ứng điều kiện giao cho cửa hàng.'),
          if (promotions.isNotEmpty) ...[
            Text('Khuyến mãi', style: Theme.of(context).textTheme.titleMedium),
            for (final promotion in promotions)
              AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(promotion.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    for (final condition in promotion.conditionLines)
                      Text(condition),
                  ])),
          ],
        ]),
      );
}
