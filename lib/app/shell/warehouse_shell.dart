import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/shared/routes.dart';

/// Warehouse Keeper navigation uses the same style as Retailer and Sales.
class WarehouseShell extends StatelessWidget {
  const WarehouseShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final branch = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: branch == 2 ? 3 : branch,
        onDestinationSelected: (index) {
          if (index == 2) {
            context.push(AppRoutes.wkScan);
            return;
          }
          final target = index == 3 ? 2 : index;
          navigationShell.goBranch(target, initialLocation: target == branch);
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Picking',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Quét QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
