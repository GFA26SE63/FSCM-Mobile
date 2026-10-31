import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// Bottom navigation of the Sales role: Trang chủ, Đơn hàng, Quét QR,
/// Đồng bộ (badge = orders still on the device), Tài khoản.
class SalesShell extends ConsumerStatefulWidget {
  const SalesShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<SalesShell> createState() => _SalesShellState();
}

class _SalesShellState extends ConsumerState<SalesShell> {
  @override
  void initState() {
    super.initState();
    // Creating the service starts the connectivity listener and the retry
    // timer; the first sync runs right after login.
    Future<void>.microtask(
        () => ref.read(syncServiceProvider.notifier).syncAll());
  }

  @override
  Widget build(BuildContext context) {
    // Keep the sync service alive while the Sales shell is on screen.
    ref.watch(syncServiceProvider.select((s) => s.phase));
    final queue =
        ref.watch(offlineQueueProvider).valueOrNull ?? const <OfflineOrder>[];
    final waiting = queue
        .where((e) =>
            e.status == SyncStatus.pending || e.status == SyncStatus.syncing)
        .length;
    final shell = widget.navigationShell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: <Widget>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Quét QR',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: waiting > 0,
              label: Text('$waiting'),
              child: const Icon(Icons.sync_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: waiting > 0,
              label: Text('$waiting'),
              child: const Icon(Icons.sync),
            ),
            label: 'Đồng bộ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
