import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_picking_screens.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_services_screens.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_scope.dart';
import 'package:fmcg/features/warehouse/presentation/widgets/picking_card.dart';

class WarehouseHomeScreen extends StatelessWidget {
  const WarehouseHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final waiting = controller.pickings
        .where((item) => item.status == PickingStatus.notStarted)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kho Thới An'),
            Text(
              'Đỗ Văn Tâm · Warehouse Keeper',
              style: TextStyle(
                color: FscmColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WarehouseNotificationsScreen(),
              ),
            ),
            icon: Badge(
              isLabelVisible: controller.unreadCount > 0,
              label: Text('${controller.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Chờ lấy',
                  value: '${controller.waitingCount}',
                  valueColor: FscmColors.info,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: MetricCard(
                  label: 'Đang lấy',
                  value: '${controller.pickingCount}',
                  valueColor: FscmColors.purple,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: MetricCard(
                  label: 'Đã xuất',
                  value: '${controller.shippedCount}',
                  valueColor: const Color(0xFF15703A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.move_to_inbox_outlined,
                  label: 'Nhập kho',
                  onTap: () => controller.setTab(3),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _QuickAction(
                  icon: Icons.qr_code_scanner,
                  label: 'Tra cứu tem',
                  onTap: () => controller.setTab(2),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _QuickAction(
                  icon: Icons.event_busy_outlined,
                  label: 'Hết hạn (${controller.expiredCount})',
                  color: FscmColors.danger,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WarehouseLabelDetailScreen(
                        labelId: 'TEM-000099',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle(
            'Picking list cần lấy',
            action: TextButton(
              onPressed: () => controller.setTab(1),
              child: const Text('Xem tất cả'),
            ),
          ),
          const SizedBox(height: 10),
          if (waiting.isEmpty)
            const EmptyState(
              icon: Icons.task_alt,
              title: 'Đã xử lý hết',
              message: 'Không còn picking list cần lấy.',
            )
          else
            ...waiting.map(
              (picking) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WarehousePickingCard(
                  picking: picking,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WarehousePickingDetailScreen(pickingId: picking.id),
                    ),
                  ),
                ),
              ),
            ),
          const Text(
            'Picking list xuất hiện sau khi đơn được duyệt. Mỗi kho nhận một danh sách riêng theo phân bổ FEFO.',
            style: TextStyle(
              color: FscmColors.muted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = FscmColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FscmCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: SizedBox(
        height: 66,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
