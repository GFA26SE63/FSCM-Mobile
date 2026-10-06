import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';
import 'package:fmcg/shared/widgets/order_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _query = '';
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final activeStatuses = {
      SalesOrderStatus.pendingSync,
      SalesOrderStatus.syncing,
      SalesOrderStatus.pendingApproval,
      SalesOrderStatus.approved,
      SalesOrderStatus.dispatched,
      SalesOrderStatus.delivering,
    };
    final orders = controller.orders.where((order) {
      final completed = !activeStatuses.contains(order.status);
      final matchesTab = _showCompleted == completed;
      final matchesQuery =
          '${order.id} ${order.retailer.name} ${order.lines.map((line) => line.product.name).join(' ')}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      return matchesTab && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SearchField(
              hint: 'Tìm mã đơn, điểm bán hoặc sản phẩm',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Đang xử lý')),
                ButtonSegment(value: true, label: Text('Đã kết thúc')),
              ],
              selected: {_showCompleted},
              onSelectionChanged: (value) =>
                  setState(() => _showCompleted = value.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: orders.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Không có đơn phù hợp',
                    message: 'Thử đổi từ khóa hoặc nhóm trạng thái.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return OrderSummaryCard(
                        order: order,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OrderDetailScreen(order: order),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});

  final SalesOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(order.id)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.retailer.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${order.retailer.id} · ${order.createdAt}',
                      style: const TextStyle(
                        color: FscmColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              OrderStatusPill(status: order.status),
            ],
          ),
          if (order.rejectionReason case final reason?) ...[
            const SizedBox(height: 14),
            FscmCard(
              color: const Color(0xFFFDECEA),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: FscmColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(
                        color: FscmColors.danger,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionTitle('Sản phẩm'),
          const SizedBox(height: 8),
          FscmCard(
            child: Column(
              children: order.lines
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
                                  line.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${line.product.sku} · ${line.quantity} thùng × ${formatVnd(line.product.price)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: FscmColors.muted,
                                  ),
                                ),
                                if (line.discountPercent > 0)
                                  Text(
                                    'Khuyến mãi −${line.discountPercent}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: FscmColors.primary,
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
          FscmCard(
            child: Column(
              children: [
                _detailRow('Tạm tính', formatVnd(order.subtotal)),
                const SizedBox(height: 8),
                _detailRow(
                  'Khuyến mãi',
                  '−${formatVnd(order.discount)}',
                  color: FscmColors.primary,
                ),
                const Divider(height: 22),
                _detailRow(
                  'Tổng thanh toán',
                  formatVnd(order.total),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Đồng bộ và xử lý'),
          const SizedBox(height: 8),
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimelineRow(
                  icon: order.wasOffline
                      ? Icons.phone_android
                      : Icons.cloud_done_outlined,
                  title: order.wasOffline
                      ? 'Tạo đơn khi offline'
                      : 'Tạo đơn online',
                  subtitle: order.createdAt,
                ),
                if (order.syncedAt != null)
                  _TimelineRow(
                    icon: Icons.sync,
                    title: 'Đồng bộ lên hệ thống',
                    subtitle: order.syncedAt!,
                  ),
                _TimelineRow(
                  icon: Icons.rule_outlined,
                  title: _statusTimelineText(order.status),
                  subtitle: 'Trạng thái hiện tại',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    final style = TextStyle(
      color: color,
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }

  String _statusTimelineText(SalesOrderStatus status) => switch (status) {
    SalesOrderStatus.pendingSync => 'Chờ thiết bị có mạng để đồng bộ',
    SalesOrderStatus.syncing => 'Đang gửi dữ liệu lên hệ thống',
    SalesOrderStatus.pendingApproval => 'Chờ Administrator hoặc Operator duyệt',
    SalesOrderStatus.approved => 'Đã duyệt và sinh picking list',
    SalesOrderStatus.dispatched => 'Kho đã xác nhận xuất hàng',
    SalesOrderStatus.delivering => 'Đơn đang được giao',
    SalesOrderStatus.delivered => 'Retailer đã xác nhận nhận hàng',
    SalesOrderStatus.rejected => 'Đơn bị từ chối',
    SalesOrderStatus.cancelled => 'Đơn đã hủy',
  };
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFE3F0EC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: FscmColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: FscmColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: controller.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notification = controller.notifications[index];
          return FscmCard(
            color: notification.isRead ? null : const Color(0xFFF2FAF7),
            onTap: () {
              controller.markNotificationRead(notification.id);
              final order = controller.orderById(notification.orderId);
              if (order != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderDetailScreen(order: order),
                  ),
                );
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  notification.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active_outlined,
                  color: FscmColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        notification.time,
                        style: const TextStyle(
                          color: FscmColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
