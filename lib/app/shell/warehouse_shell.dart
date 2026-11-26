import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/shared/widgets/permission_navigation_bar.dart';

/// Warehouse Keeper navigation uses the same style as Retailer and Sales.
class WarehouseShell extends StatelessWidget {
  const WarehouseShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final branch = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: PermissionNavigationBar(
        paths: const ['/wk/home', '/wk/picking', '/wk/account'],
        selectedIndex: branch,
        onDestinationSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == branch),
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Nhập/Xuất',
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
