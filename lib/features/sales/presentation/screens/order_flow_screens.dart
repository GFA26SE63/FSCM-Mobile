import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';
import 'package:fmcg/shared/widgets/order_widgets.dart';

class RetailerSelectionScreen extends StatefulWidget {
  const RetailerSelectionScreen({super.key});

  @override
  State<RetailerSelectionScreen> createState() =>
      _RetailerSelectionScreenState();
}

class _RetailerSelectionScreenState extends State<RetailerSelectionScreen> {
  String _query = '';
  bool _onlyAssignedArea = true;

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final retailers = controller.retailers.where((retailer) {
      final matchesQuery = '${retailer.name} ${retailer.id} ${retailer.address}'
          .toLowerCase()
          .contains(_query.toLowerCase());
      return matchesQuery && (!_onlyAssignedArea || retailer.isInSalesArea);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chọn điểm bán'),
            Text(
              'Nhóm Q12-A · Khu vực Quận 12',
              style: TextStyle(
                fontSize: 12,
                color: FscmColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SearchField(
            hint: 'Tìm tên, mã điểm bán hoặc địa chỉ',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          FilterChip(
            label: const Text('Chỉ điểm bán được phân quyền'),
            selected: _onlyAssignedArea,
            onSelected: (value) => setState(() => _onlyAssignedArea = value),
          ),
          const SizedBox(height: 10),
          ...retailers.map(
            (retailer) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FscmCard(
                onTap: retailer.isInSalesArea
                    ? () {
                        controller.selectRetailer(retailer);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProductCatalogScreen(),
                          ),
                        );
                      }
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${retailer.name} nằm ngoài khu vực được phân quyền.',
                          ),
                        ),
                      ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F0EC),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: FscmColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            retailer.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            retailer.address,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: FscmColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${retailer.id} · ${retailer.area} · Hạng ${retailer.tier}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      retailer.isInSalesArea
                          ? Icons.chevron_right
                          : Icons.lock_outline,
                      color: FscmColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (retailers.isEmpty)
            const EmptyState(
              icon: Icons.store_mall_directory_outlined,
              title: 'Không tìm thấy điểm bán',
              message: 'Thử thay đổi từ khóa hoặc bộ lọc khu vực.',
            ),
        ],
      ),
    );
  }
}

class ProductCatalogScreen extends StatefulWidget {
  const ProductCatalogScreen({super.key});

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  String _query = '';
  String _category = 'Tất cả';

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final retailer = controller.selectedRetailer;
    final categories = [
      'Tất cả',
      ...controller.products.map((item) => item.category).toSet(),
    ];
    final products = controller.products.where((product) {
      final matchesCategory =
          _category == 'Tất cả' || product.category == _category;
      final matchesQuery = '${product.name} ${product.sku}'
          .toLowerCase()
          .contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn sản phẩm'),
            Text(
              retailer?.name ?? 'Chưa chọn điểm bán',
              style: const TextStyle(
                fontSize: 12,
                color: FscmColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Giỏ hàng',
            onPressed: controller.hasCart
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                  )
                : null,
            icon: Badge(
              isLabelVisible: controller.cartQuantity > 0,
              label: Text('${controller.cartQuantity}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(
              hint: 'Tìm tên hoặc mã SKU',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(categories[index]),
                selected: _category == categories[index],
                onSelected: (_) =>
                    setState(() => _category = categories[index]),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = products[index];
                final quantity = controller.quantityFor(product);
                return FscmCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EAFE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: FscmColors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${product.sku} · ${product.pack}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: FscmColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  formatVnd(product.price),
                                  style: const TextStyle(
                                    color: FscmColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Khả dụng ${controller.maxQuantityFor(product)} thùng${controller.isOnline ? '' : ' · dữ liệu máy'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: FscmColors.muted,
                              ),
                            ),
                          ),
                          _QuantityControl(
                            quantity: quantity,
                            canDecrease: quantity > 0,
                            canIncrease:
                                quantity < controller.maxQuantityFor(product),
                            onDecrease: () =>
                                controller.changeQuantity(product, -10),
                            onIncrease: () =>
                                controller.changeQuantity(product, 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomSheet: controller.hasCart
          ? SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: ElevatedButton(
                  key: const Key('openCartButton'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                  ),
                  child: Text(
                    'Xem giỏ hàng · ${controller.cartQuantity} thùng · ${formatVnd(controller.cartTotal)}',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: canDecrease ? onDecrease : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filled(
          onPressed: canIncrease ? onIncrease : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FscmCard(
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: FscmColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.selectedRetailer?.name ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        controller.selectedRetailer?.address ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: FscmColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...controller.cartLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FscmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              controller.removeFromCart(line.product),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: FscmColors.danger,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${line.product.sku} · ${formatVnd(line.product.price)}/thùng',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: FscmColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QuantityControl(
                          quantity: line.quantity,
                          canDecrease: true,
                          canIncrease:
                              line.quantity <
                              controller.maxQuantityFor(line.product),
                          onDecrease: () =>
                              controller.changeQuantity(line.product, -10),
                          onIncrease: () =>
                              controller.changeQuantity(line.product, 10),
                        ),
                        const Spacer(),
                        Text(
                          formatVnd(line.total),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    if (line.discountPercent > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Khuyến mãi: giảm ${line.discountPercent}% (−${formatVnd(line.discount)})',
                        style: const TextStyle(
                          color: FscmColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          OrderTotalsCard(
            subtotal: controller.cartSubtotal,
            discount: controller.cartDiscount,
            total: controller.cartTotal,
          ),
          const SizedBox(height: 90),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: ElevatedButton(
            onPressed: controller.hasCart
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OrderReviewScreen(),
                    ),
                  )
                : null,
            child: const Text('Tiếp tục xác nhận đơn'),
          ),
        ),
      ),
    );
  }
}

class OrderReviewScreen extends StatelessWidget {
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!controller.isOnline)
            const FscmCard(
              color: Color(0xFFFFF5DE),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: Color(0xFF9A6700)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đơn sẽ được lưu trên máy. Giá và khuyến mãi được tính lại khi đồng bộ.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          if (!controller.isOnline) const SizedBox(height: 12),
          const SectionTitle('Điểm bán'),
          const SizedBox(height: 8),
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.selectedRetailer?.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${controller.selectedRetailer?.id} · ${controller.selectedRetailer?.address}',
                  style: const TextStyle(
                    color: FscmColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Sản phẩm và khuyến mãi'),
          const SizedBox(height: 8),
          FscmCard(
            child: Column(
              children: controller.cartLines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${line.product.name} × ${line.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (line.discountPercent > 0)
                                  Text(
                                    'Giảm ${line.discountPercent}%',
                                    style: const TextStyle(
                                      color: FscmColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            formatVnd(line.total),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          OrderTotalsCard(
            subtotal: controller.cartSubtotal,
            discount: controller.cartDiscount,
            total: controller.cartTotal,
          ),
          const SizedBox(height: 18),
          const SectionTitle('Thanh toán'),
          const SizedBox(height: 8),
          const FscmCard(
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: FscmColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cơ chế thanh toán sẽ được xác nhận theo chính sách của điểm bán.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: ElevatedButton(
            key: const Key('submitOrderButton'),
            onPressed: () {
              final order = controller.submitOrder();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => OrderSuccessScreen(order: order),
                ),
              );
            },
            child: Text(
              controller.isOnline ? 'Gửi đơn hàng' : 'Lưu đơn trên máy',
            ),
          ),
        ),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    final offline = order.status == SalesOrderStatus.pendingSync;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1F1EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  offline ? Icons.cloud_done_outlined : Icons.check,
                  size: 44,
                  color: FscmColors.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                offline ? 'Đã lưu đơn trên máy' : 'Đã gửi đơn hàng',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                offline
                    ? '${order.id} sẽ tự đồng bộ khi thiết bị có mạng.'
                    : '${order.id} đang chờ Administrator hoặc Operator duyệt.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: FscmColors.muted, height: 1.5),
              ),
              const SizedBox(height: 18),
              OrderStatusPill(status: order.status),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  SalesScope.of(context, listen: false).setTab(1);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Xem danh sách đơn hàng'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  SalesScope.of(context, listen: false).setTab(0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
