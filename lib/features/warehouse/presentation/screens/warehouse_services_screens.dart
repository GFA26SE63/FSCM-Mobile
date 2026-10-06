import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_picking_screens.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_presenters.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_scope.dart';
import 'package:fmcg/shared/widgets/experience_switcher.dart';
import 'package:fmcg/shared/widgets/inventory_widgets.dart';

class WarehouseScannerScreen extends StatelessWidget {
  const WarehouseScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final demoIds = [
      'TEM-000131',
      'TEM-000118',
      if (controller.labels.containsKey('TEM-000204')) 'TEM-000204',
      'TEM-000099',
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ScanFrame(
            height: 230,
            message:
                'Quét tem bất kỳ để xem batch, tồn, quan hệ tem và lịch sử.',
          ),
          const SizedBox(height: 18),
          const SectionTitle('Tem minh họa'),
          const SizedBox(height: 9),
          ...demoIds.map((id) {
            final label = controller.labelById(id)!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FscmCard(
                padding: EdgeInsets.zero,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WarehouseLabelDetailScreen(labelId: id),
                  ),
                ),
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: Text(id),
                  subtitle: Text(
                    '${label.sku} · ${label.quantity} thùng · ${stockStatusLabel(label.status)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class WarehouseLabelDetailScreen extends StatelessWidget {
  const WarehouseLabelDetailScreen({super.key, required this.labelId});

  final String labelId;

  @override
  Widget build(BuildContext context) {
    final label = WarehouseScope.of(context).labelById(labelId);
    if (label == null) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy tem.')));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Tem ${label.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InventoryLabelCard(
            labelId: label.id,
            sku: label.sku,
            quantity: label.quantity,
            batchCode: label.batchCode,
            expiryDate: label.expiryDate,
            location: label.location,
            destination: label.pickingId,
            status: stockStatusLabel(label.status),
            statusColor: stockStatusColor(label.status),
          ),
          const SizedBox(height: 12),
          FscmCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Số lượng hiện tại',
                  value: '${label.quantity} thùng',
                ),
                InfoRow(label: 'Tem cha', value: label.parentId ?? '—'),
                InfoRow(
                  label: 'Tem con đã tách',
                  value: label.childIds.isEmpty
                      ? '—'
                      : label.childIds.join(', '),
                ),
                InfoRow(
                  label: 'Lô nhà sản xuất',
                  value: label.manufacturerLot?.isNotEmpty == true
                      ? label.manufacturerLot!
                      : '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Lịch sử tem'),
          const SizedBox(height: 9),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: label.history.reversed
                  .map(
                    (entry) => ListTile(
                      leading: const Icon(
                        Icons.circle,
                        size: 10,
                        color: Color(0xFF8A4B0C),
                      ),
                      title: Text(
                        entry.description,
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      subtitle: Text(entry.time),
                      trailing: entry.quantityChange == null
                          ? null
                          : Text(
                              '${entry.quantityChange! > 0 ? '+' : ''}${entry.quantityChange}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã in lại tem ${label.id}.')),
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('In lại tem'),
          ),
        ],
      ),
    );
  }
}

class WarehouseNotificationsScreen extends StatelessWidget {
  const WarehouseNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: controller.markAllNotificationsRead,
            child: const Text('Đọc tất cả'),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: controller.notifications.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = controller.notifications[index];
          return ListTile(
            tileColor: item.isRead ? Colors.white : const Color(0xFFF4F7FF),
            leading: Icon(
              Icons.circle,
              size: 10,
              color: item.isRead ? FscmColors.border : FscmColors.info,
            ),
            title: Text(item.message),
            subtitle: Text(item.time),
            onTap: () {
              controller.markNotificationRead(item.id);
              if (item.orderId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WarehousePickingDetailScreen(pickingId: item.orderId!),
                  ),
                );
              } else if (item.message.contains('TEM-000099')) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const WarehouseLabelDetailScreen(labelId: 'TEM-000099'),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class WarehouseAccountScreen extends StatelessWidget {
  const WarehouseAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FscmCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF8A4B0C),
                  child: Text(
                    'VT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đỗ Văn Tâm',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Warehouse Keeper · Kho Thới An (WH-TA)',
                        style: TextStyle(
                          color: FscmColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        '0912 440 118',
                        style: TextStyle(
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
          const FscmCard(
            child: Column(
              children: [
                InfoRow(label: 'Máy in tem', value: 'XP-P323B · đã kết nối'),
                InfoRow(label: 'Kho được gán', value: 'Kho Thới An'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FscmCard(
            padding: EdgeInsets.zero,
            child: ListTile(
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
                  builder: (_) => const WarehouseNotificationsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const ExperienceSwitcher(),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: controller.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất Warehouse Keeper'),
          ),
        ],
      ),
    );
  }
}
