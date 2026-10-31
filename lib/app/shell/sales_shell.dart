import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// Bottom navigation of the Sales role matching FSCM_Prototype_Prod_v1.1:
/// Trang chủ, Đơn hàng, Đồng bộ (badge = orders still on the device), Tài khoản.
class SalesShell extends ConsumerStatefulWidget {
  const SalesShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends ConsumerState<SalesShell> {
  static const List<int> _branchForTab = <int>[0, 1, 3, 4];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(syncServiceProvider.notifier).syncAll());
  }

  int _tabForBranch(int branchIndex) {
    final idx = _branchForTab.indexOf(branchIndex);
    return idx >= 0 ? idx : 0;
  }

  void _onSelectTab(int tabIndex) {
    final branch = _branchForTab[tabIndex];
    widget.navigationShell.goBranch(
      branch,
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncServiceProvider.select((s) => s.phase));
    final queue =
        ref.watch(offlineQueueProvider).valueOrNull ?? const <OfflineOrder>[];
    final waiting = queue
        .where((e) =>
            e.status == SyncStatus.pending || e.status == SyncStatus.syncing)
        .length;
    final activeTab = _tabForBranch(widget.navigationShell.currentIndex);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _SalesTabButton(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Trang chủ',
                active: activeTab == 0,
                onTap: () => _onSelectTab(0),
              ),
            ),
            Expanded(
              child: _SalesTabButton(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Đơn hàng',
                active: activeTab == 1,
                onTap: () => _onSelectTab(1),
              ),
            ),
            Expanded(
              child: _SalesTabButton(
                icon: Icons.cloud_upload_outlined,
                activeIcon: Icons.cloud_upload,
                label: 'Đồng bộ',
                badgeCount: waiting,
                active: activeTab == 2,
                onTap: () => _onSelectTab(2),
              ),
            ),
            Expanded(
              child: _SalesTabButton(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Tài khoản',
                active: activeTab == 3,
                onTap: () => _onSelectTab(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesTabButton extends StatelessWidget {
  const _SalesTabButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(active ? activeIcon : icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          if (badgeCount > 0)
            Positioned(
              top: 6,
              right: 22,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
