import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/domain/sales_models.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/features/sales/presentation/screens/insights_screens.dart';
import 'package:fmcg/features/sales/presentation/screens/order_flow_screens.dart';
import 'package:fmcg/features/sales/presentation/screens/orders_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final pendingApproval = controller.orders
        .where((order) => order.status == SalesOrderStatus.pendingApproval)
        .length;
    final rejected = controller.orders
        .where((order) => order.status == SalesOrderStatus.rejected)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào, Nguyễn Văn An'),
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
        actions: [
          TextButton.icon(
            onPressed: controller.toggleConnectivity,
            icon: Icon(
              Icons.circle,
              size: 9,
              color: controller.isOnline
                  ? FscmColors.primary
                  : FscmColors.warning,
            ),
            label: Text(controller.isOnline ? 'Online' : 'Offline'),
          ),
          Badge(
            isLabelVisible: controller.unreadNotificationCount > 0,
            label: Text('${controller.unreadNotificationCount}'),
            child: IconButton(
              tooltip: 'Thông báo',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FscmCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F0EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync, color: FscmColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${controller.pendingSyncCount} đơn chờ đồng bộ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Dữ liệu trên máy lúc ${controller.lastSync}',
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
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => controller.setTab(3),
                  child: const Text('Mở hàng đợi đồng bộ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            key: const Key('newOrderButton'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RetailerSelectionScreen(),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Tạo đơn hàng mới'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: MetricCard(label: 'Đơn hôm nay', value: '5'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Chờ duyệt',
                  value: '$pendingApproval',
                  valueColor: FscmColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Bị từ chối',
                  value: '$rejected',
                  valueColor: FscmColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionTitle('Công cụ nhanh'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _QuickAction(
                icon: Icons.sell_outlined,
                label: 'Khuyến mãi đang chạy',
                onTap: () => _open(context, const PromotionsScreen()),
              ),
              _QuickAction(
                icon: Icons.bar_chart,
                label: 'Doanh số của tôi',
                onTap: () => _open(context, const SalesDashboardScreen()),
              ),
              _QuickAction(
                icon: Icons.emoji_events_outlined,
                label: 'Bảng xếp hạng',
                onTap: () => _open(context, const RankingScreen()),
              ),
              _QuickAction(
                icon: Icons.add_business_outlined,
                label: 'Khai báo retailer',
                onTap: () => _open(context, const RetailerLeadsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SectionTitle(
            'Thông báo mới',
            action: TextButton(
              onPressed: () => _open(context, const NotificationsScreen()),
              child: const Text('Xem tất cả'),
            ),
          ),
          const SizedBox(height: 8),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: controller.notifications
                  .take(2)
                  .map(
                    (notification) => ListTile(
                      leading: Icon(
                        Icons.circle,
                        size: 9,
                        color: notification.isRead
                            ? FscmColors.border
                            : FscmColors.primary,
                      ),
                      title: Text(
                        notification.message,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      subtitle: Text(notification.time),
                      onTap: () => _openNotification(context, notification),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openNotification(BuildContext context, SalesNotification notification) {
    final controller = SalesScope.of(context, listen: false);
    controller.markNotificationRead(notification.id);
    final order = controller.orderById(notification.orderId);
    if (order != null) {
      _open(context, OrderDetailScreen(order: order));
    }
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FscmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: FscmColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
