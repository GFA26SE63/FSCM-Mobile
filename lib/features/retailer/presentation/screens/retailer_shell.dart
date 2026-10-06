import 'package:flutter/material.dart';
import 'package:fmcg/features/retailer/presentation/retailer_scope.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_orders_screen.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_receipt_screens.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_services_screens.dart';

class RetailerShell extends StatelessWidget {
  const RetailerShell({super.key});

  static const _pages = <Widget>[
    RetailerOrdersScreen(),
    RetailerScanHubScreen(),
    RetailerLoyaltyScreen(),
    RetailerAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    return Scaffold(
      body: IndexedStack(index: controller.currentTab, children: _pages),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: controller.currentTab,
        onDestinationSelected: controller.setTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Quét QR',
          ),
          const NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Điểm & hạng',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: controller.unreadCount > 0,
              label: Text('${controller.unreadCount}'),
              child: const Icon(Icons.person_outline),
            ),
            selectedIcon: const Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
