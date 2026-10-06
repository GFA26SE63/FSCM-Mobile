import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/retailer/presentation/retailer_scope.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_receipt_screens.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_services_screens.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';
import 'package:fmcg/shared/widgets/order_widgets.dart';

class RetailerOrdersScreen extends StatefulWidget {
  const RetailerOrdersScreen({super.key});

  @override
  State<RetailerOrdersScreen> createState() => _RetailerOrdersScreenState();
}

class _RetailerOrdersScreenState extends State<RetailerOrdersScreen> {
  String _query = '';
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final activeStatuses = {
      SalesOrderStatus.pendingApproval,
      SalesOrderStatus.approved,
      SalesOrderStatus.dispatched,
      SalesOrderStatus.delivering,
    };
    final visibleOrders = controller.orders.where((order) {
      final isCompleted = !activeStatuses.contains(order.status);
      return isCompleted == _completed &&
          '${order.id} ${order.lines.map((line) => line.product.name).join(' ')}'
              .toLowerCase()
              .contains(_query.toLowerCase());
    }).toList();
    final delivering = controller.orders
        .where((order) => order.status == SalesOrderStatus.delivering)
        .firstOrNull;
    final paidTotal = controller.orders
        .where((order) => order.payment.isPaid)
        .fold<int>(0, (sum, order) => sum + order.total);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(controller.retailer.name),
            Text(
              'Mã ${controller.retailer.id}',
              style: const TextStyle(
                fontSize: 12,
                color: FscmColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Badge(
            isLabelVisible: controller.unreadCount > 0,
            label: Text('${controller.unreadCount}'),
            child: IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RetailerNotificationsScreen(),
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
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Đơn tháng 9',
                  value: '${controller.orders.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Đã thanh toán',
                  value: _shortMoney(paidTotal),
                  valueColor: FscmColors.primary,
                ),
              ),
            ],
          ),
          if (controller.outstandingBalance > 0) ...[
            const SizedBox(height: 10),
            FscmCard(
              color: const Color(0xFFFFF5DE),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RetailerPaymentsScreen(),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF9A6700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Công nợ còn phải trả ${formatVnd(controller.outstandingBalance)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
          if (delivering != null) ...[
            const SizedBox(height: 10),
            FscmCard(
              color: const Color(0xFFF1EAFE),
              onTap: () => _openOrder(context, delivering.id),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    color: FscmColors.purple,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${delivering.id} đang giao · chạm để xem và nhận hàng',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SearchField(
            hint: 'Tìm mã đơn hoặc tên sản phẩm',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Đang xử lý')),
              ButtonSegment(value: true, label: Text('Đã kết thúc')),
            ],
            selected: {_completed},
            onSelectionChanged: (value) =>
                setState(() => _completed = value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          ...visibleOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrderSummaryCard(
                order: order,
                onTap: () => _openOrder(context, order.id),
              ),
            ),
          ),
          if (visibleOrders.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Không có đơn phù hợp',
              message: 'Thử đổi từ khóa hoặc nhóm trạng thái.',
            ),
        ],
      ),
    );
  }

  void _openOrder(BuildContext context, String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RetailerOrderDetailScreen(orderId: orderId),
      ),
    );
  }

  String _shortMoney(int amount) =>
      '${(amount / 1000000).toStringAsFixed(1)}tr';
}

class RetailerOrderDetailScreen extends StatelessWidget {
  const RetailerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final order = controller.orderById(orderId);
    if (order == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy đơn hàng.')),
      );
    }
    final complaint = controller.complaints
        .where((item) => item.orderId == order.id)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(order.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tạo bởi ${order.createdBy} · ${order.createdAt}',
                  style: const TextStyle(
                    color: FscmColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
              OrderStatusPill(status: order.status),
            ],
          ),
          if (order.rejectionReason case final reason?) ...[
            const SizedBox(height: 12),
            FscmCard(
              color: const Color(0xFFFDECEA),
              child: Text(
                reason,
                style: const TextStyle(color: FscmColors.danger, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const SectionTitle('Sản phẩm và batch'),
          const SizedBox(height: 8),
          OrderLineListCard(
            lines: order.lines,
            showBatches: order.lines.any((line) => line.batches.isNotEmpty),
          ),
          const SizedBox(height: 12),
          OrderTotalsCard(
            subtotal: order.subtotal,
            discount: order.discount,
            total: order.total,
          ),
          const SizedBox(height: 18),
          const SectionTitle('Thanh toán và quyền lợi'),
          const SizedBox(height: 8),
          FscmCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Phương thức',
                  value: paymentMethodLabel(order.payment.method),
                ),
                InfoRow(
                  label: 'Trạng thái',
                  value: _paymentStatus(order),
                  valueColor: order.payment.isPaid ? FscmColors.primary : null,
                ),
                InfoRow(
                  label: 'Điểm loyalty',
                  value: order.status == SalesOrderStatus.rejected
                      ? 'Không tích điểm'
                      : '+${order.total ~/ 100000} điểm khi đủ điều kiện',
                ),
              ],
            ),
          ),
          if (order.delivery case final delivery?) ...[
            const SizedBox(height: 18),
            const SectionTitle('Thông tin giao hàng'),
            const SizedBox(height: 8),
            FscmCard(
              child: Column(
                children: [
                  InfoRow(label: 'Xe giao hàng', value: delivery.vehiclePlate),
                  InfoRow(
                    label: 'Tài xế',
                    value: '${delivery.driverName} · ${delivery.driverPhone}',
                  ),
                  InfoRow(label: 'Xuất phát', value: delivery.departedAt),
                ],
              ),
            ),
          ],
          if (complaint != null) ...[
            const SizedBox(height: 18),
            const SectionTitle('Khiếu nại đã gửi'),
            const SizedBox(height: 8),
            FscmCard(
              color: const Color(0xFFFFF5DE),
              child: Text(
                '${complaint.batchCode}: phiếu ${complaint.expectedQuantity}, thực nhận ${complaint.actualQuantity} thùng · ${complaint.evidenceCount} ảnh.',
                style: const TextStyle(height: 1.4),
              ),
            ),
          ],
        ],
      ),
      bottomSheet: order.status == SalesOrderStatus.delivering
          ? BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RetailerComplaintScreen(orderId: order.id),
                        ),
                      ),
                      child: const Text('Gửi khiếu nại'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RetailerReceiptScanScreen(orderId: order.id),
                        ),
                      ),
                      child: const Text('Quét nhận hàng'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  String _paymentStatus(SalesOrder order) {
    if (order.status == SalesOrderStatus.rejected) {
      return 'Không phát sinh';
    }
    if (order.payment.isPaid) {
      return 'Đã thanh toán${order.payment.paidAt == null ? '' : ' · ${order.payment.paidAt}'}';
    }
    if (order.payment.method == PaymentMethod.credit) {
      return 'Còn ${formatVnd(order.total - order.payment.paidAmount)} · hạn ${order.payment.dueDate}';
    }
    return 'Chưa thanh toán';
  }
}

class RetailerNotificationsScreen extends StatelessWidget {
  const RetailerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: controller.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = controller.notifications[index];
          return FscmCard(
            color: item.isRead ? null : const Color(0xFFF2FAF7),
            onTap: () {
              controller.markNotificationRead(item.id);
              if (item.orderId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RetailerOrderDetailScreen(orderId: item.orderId!),
                  ),
                );
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isRead
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
                        item.message,
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.time,
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
