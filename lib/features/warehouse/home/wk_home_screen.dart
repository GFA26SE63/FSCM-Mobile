import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_list_tile.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Warehouse Keeper home screen matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.warehouse` HOME).
class WkHomeScreen extends ConsumerWidget {
  const WkHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pickings =
        ref.watch(pickingListsProvider).valueOrNull ?? const <PickingList>[];
    final transfers =
        ref.watch(transfersProvider).valueOrNull ?? const <Transfer>[];
    final todo =
        pickings.where((p) => p.status != PickingStatus.shipped).toList();
    int count(PickingStatus s) => pickings.where((p) => p.status == s).length;
    final incoming =
        transfers.where((t) => t.status == TransferStatus.inTransit).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              user?.warehouseName ?? 'Kho Thới An',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              '${user?.fullName ?? 'Đỗ Văn Tâm'} · Warehouse Keeper',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: NotificationBellButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pickingListsProvider);
          ref.invalidate(transfersProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _WkStatCard(
                    label: 'Chờ soạn',
                    value: '${count(PickingStatus.pending)}',
                    valueColor: const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WkStatCard(
                    label: 'Đang soạn',
                    value: '${count(PickingStatus.picking)}',
                    valueColor: const Color(0xFF6D28D9),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WkStatCard(
                    label: 'Đã xuất',
                    value: '${count(PickingStatus.shipped)}',
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _WkShortcutCard(
                    icon: Icons.local_shipping_outlined,
                    iconColor: AppColors.primary,
                    label: incoming.isEmpty
                        ? 'Nhập kho'
                        : 'Nhập kho (${incoming.length})',
                    onTap: () => context.go(AppRoutes.wkTransfers),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WkShortcutCard(
                    icon: Icons.search,
                    iconColor: AppColors.primary,
                    label: 'Tra cứu tem',
                    onTap: () => context.push(AppRoutes.wkLabelLookup),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _WkShortcutCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppColors.danger,
                    label: 'Hết hạn (1)',
                    onTap: () => context.push(AppRoutes.wkLabelLookup),
                  ),
                ),
              ],
            ),
            SectionTitle(
              'Phần giao cần soạn',
              trailing: TextButton(
                onPressed: () => context.go(AppRoutes.wkPicking),
                child: const Text('Xem tất cả'),
              ),
            ),
            if (todo.isEmpty)
              const EmptyState(
                icon: Icons.task_alt,
                title: 'Không còn phần giao cần soạn.',
                message:
                    'Phần giao xuất hiện ngay khi Admin / Operator duyệt đơn.',
              )
            else
              for (final p in todo) PickingListTile(list: p),
          ],
        ),
      ),
    );
  }
}

class _WkStatCard extends StatelessWidget {
  const _WkStatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _WkShortcutCard extends StatelessWidget {
  const _WkShortcutCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
