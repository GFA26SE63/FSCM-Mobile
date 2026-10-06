import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/domain/sales_models.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/features/sales/presentation/screens/orders_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    final pending = controller.orders
        .where((order) => order.status == SalesOrderStatus.pendingSync)
        .toList();
    final syncing = controller.orders
        .where((order) => order.status == SalesOrderStatus.syncing)
        .toList();
    final synced = controller.orders
        .where((order) => order.wasOffline && order.syncedAt != null)
        .toList();
    final groups = [pending, syncing, synced];
    final orders = groups[_tab];

    return Scaffold(
      appBar: AppBar(title: const Text('Đồng bộ dữ liệu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FscmCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: controller.isOnline
                          ? const Color(0xFFE1F1EC)
                          : const Color(0xFFFFF5DE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      controller.isOnline
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: controller.isOnline
                          ? FscmColors.primary
                          : const Color(0xFF9A6700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.isOnline
                              ? 'Thiết bị đang online'
                              : 'Thiết bị đang offline',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Lần đồng bộ gần nhất ${controller.lastSync}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: FscmColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: controller.isOnline,
                    onChanged: (_) => controller.toggleConnectivity(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text('Chưa (${pending.length})'),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Đang (${syncing.length})'),
                  ),
                  ButtonSegment(value: 2, label: Text('Đã (${synced.length})')),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) =>
                    setState(() => _tab = selection.first),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: orders.isEmpty
                ? EmptyState(
                    icon: _tab == 2 ? Icons.cloud_done_outlined : Icons.sync,
                    title: _tab == 0
                        ? 'Không có đơn chờ đồng bộ'
                        : _tab == 1
                        ? 'Không có tiến trình đang chạy'
                        : 'Chưa có lịch sử đồng bộ',
                    message: _tab == 0
                        ? 'Các đơn tạo khi offline sẽ xuất hiện tại đây.'
                        : 'Trạng thái đồng bộ được cập nhật chi tiết theo từng đơn.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        OrderCard(order: orders[index]),
                  ),
          ),
        ],
      ),
      bottomSheet: _tab == 0 && pending.isNotEmpty
          ? SafeArea(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: ElevatedButton.icon(
                  onPressed: controller.isOnline && !controller.isSyncing
                      ? () async {
                          setState(() => _tab = 1);
                          await controller.syncPendingOrders();
                          if (!context.mounted) return;
                          setState(() => _tab = 2);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đồng bộ đơn hàng thành công.'),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    controller.isOnline
                        ? 'Đồng bộ ngay'
                        : 'Cần có mạng để đồng bộ',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
