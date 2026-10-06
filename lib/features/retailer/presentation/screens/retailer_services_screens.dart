import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/retailer/presentation/retailer_scope.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_orders_screen.dart';
import 'package:fmcg/shared/widgets/experience_switcher.dart';
import 'package:fmcg/shared/widgets/order_widgets.dart';

class RetailerPaymentsScreen extends StatelessWidget {
  const RetailerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final paidOrders = controller.orders
        .where((order) => order.payment.isPaid)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FscmCard(
            color: controller.outstandingBalance > 0
                ? const Color(0xFFFFF5DE)
                : const Color(0xFFE1F1EC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Công nợ còn phải trả',
                  style: TextStyle(color: FscmColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 5),
                Text(
                  formatVnd(controller.outstandingBalance),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${controller.outstandingOrders.length} đơn chưa thanh toán đủ',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: FscmColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (controller.outstandingOrders.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionTitle('Công nợ'),
            const SizedBox(height: 8),
            ...controller.outstandingOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FscmCard(
                  onTap: () => _openOrder(context, order.id),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Hạn ${order.payment.dueDate} · đã trả ${formatVnd(order.payment.paidAmount)}',
                              style: const TextStyle(
                                color: FscmColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatVnd(order.total - order.payment.paidAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF9A6700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionTitle('Lịch sử đã thanh toán'),
          const SizedBox(height: 8),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: paidOrders
                  .map(
                    (order) => ListTile(
                      title: Text(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${paymentMethodLabel(order.payment.method)} · ${order.payment.paidAt}',
                      ),
                      trailing: Text(
                        formatVnd(order.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => _openOrder(context, order.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _openOrder(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RetailerOrderDetailScreen(orderId: id),
      ),
    );
  }
}

class RetailerLoyaltyScreen extends StatelessWidget {
  const RetailerLoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final progress = (controller.loyaltyPoints / 600).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Điểm & hạng thành viên')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF755B05), Color(0xFFD8A91B)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'HẠNG VÀNG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '${controller.loyaltyPoints} điểm',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  color: Colors.white,
                  backgroundColor: Colors.white30,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 7),
                Text(
                  'Còn ${600 - controller.loyaltyPoints} điểm để lên hạng Kim cương',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: controller.loyaltyPoints >= 50
                ? () => _redeem(context)
                : null,
            icon: const Icon(Icons.redeem_outlined),
            label: const Text('Đổi 50 điểm lấy ưu đãi'),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Lịch sử điểm'),
          const SizedBox(height: 8),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: controller.loyaltyHistory
                  .map(
                    (item) => ListTile(
                      leading: Text(
                        item.date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FscmColors.muted,
                        ),
                      ),
                      title: Text(
                        item.description,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      trailing: Text(
                        item.isPending
                            ? 'Chờ cộng'
                            : '${item.points > 0 ? '+' : ''}${item.points}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: item.isPending
                              ? FscmColors.muted
                              : item.points > 0
                              ? const Color(0xFF15703A)
                              : FscmColors.danger,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Quyền lợi theo hạng'),
          const SizedBox(height: 8),
          const FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: Text('Thành viên'),
                  subtitle: Text('Từ 0 điểm · tích và đổi điểm'),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text('Bạc'),
                  subtitle: Text('Từ 100 điểm · giảm thêm 1%'),
                ),
                Divider(height: 1),
                ListTile(
                  tileColor: Color(0xFFFFF7E6),
                  title: Text('Vàng'),
                  subtitle: Text('Từ 300 điểm · giảm thêm 2%'),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text('Kim cương'),
                  subtitle: Text('Từ 600 điểm · giảm thêm 3% và ưu tiên giao'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _redeem(BuildContext context) {
    RetailerScope.of(context, listen: false).redeemPoints(50);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã đổi 50 điểm. Ưu đãi sẽ áp dụng cho đơn đủ điều kiện tiếp theo.',
        ),
      ),
    );
  }
}

class RetailerAccountScreen extends StatelessWidget {
  const RetailerAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FscmCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE3F0EC),
                  child: Icon(Icons.storefront, color: FscmColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.retailer.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Mã ${controller.retailer.id} · Hạng ${controller.retailer.tier}',
                        style: const TextStyle(
                          color: FscmColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        controller.retailer.address,
                        style: const TextStyle(
                          color: FscmColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.notifications_outlined,
                    color: FscmColors.primary,
                  ),
                  title: const Text('Thông báo'),
                  trailing: Badge(
                    isLabelVisible: controller.unreadCount > 0,
                    label: Text('${controller.unreadCount}'),
                    child: const Icon(Icons.chevron_right),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RetailerNotificationsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: FscmColors.primary,
                  ),
                  title: const Text('Thanh toán và công nợ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RetailerPaymentsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.workspace_premium_outlined,
                    color: FscmColors.primary,
                  ),
                  title: const Text('Điểm và quyền lợi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => controller.setTab(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const ExperienceSwitcher(),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: controller.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất Retailer'),
          ),
        ],
      ),
    );
  }
}
