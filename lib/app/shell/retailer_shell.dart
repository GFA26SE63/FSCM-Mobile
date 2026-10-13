import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation of the Retailer role: Đơn hàng, Quét QR, Tài khoản.
class RetailerShell extends StatelessWidget {
  const RetailerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i,
            initialLocation: i == navigationShell.currentIndex),
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
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
