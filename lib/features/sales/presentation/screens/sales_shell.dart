import 'package:flutter/material.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/features/sales/presentation/screens/account_screen.dart';
import 'package:fmcg/features/sales/presentation/screens/home_screen.dart';
import 'package:fmcg/features/sales/presentation/screens/order_flow_screens.dart';
import 'package:fmcg/features/sales/presentation/screens/orders_screen.dart';
import 'package:fmcg/features/sales/presentation/screens/sync_screen.dart';

class SalesShell extends StatelessWidget {
  const SalesShell({super.key});

  static const _pages = <Widget>[
    HomeScreen(),
    OrdersScreen(),
    ScannerScreen(),
    SyncScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);

    return Scaffold(
      body: Column(
        children: [
          if (!controller.isOnline)
            OfflineBanner(lastSync: controller.lastSync),
          Expanded(
            child: IndexedStack(index: controller.currentTab, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: controller.currentTab,
        indicatorColor: const Color(0xFFE3F0EC),
        onDestinationSelected: controller.setTab,
        destinations: [
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
              isLabelVisible: controller.pendingSyncCount > 0,
              label: Text('${controller.pendingSyncCount}'),
              child: const Icon(Icons.sync_outlined),
            ),
            selectedIcon: const Icon(Icons.sync),
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

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ScanFrame(
            message: 'Đưa mã QR điểm bán hoặc tem đơn hàng vào khung quét.',
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              controller.selectRetailer(controller.retailers.first);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProductCatalogScreen(),
                ),
              );
            },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Giả lập quét điểm bán 10004127'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tem DH-1021 đã được nhận diện.')),
            ),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Giả lập quét tem đơn hàng'),
          ),
        ],
      ),
    );
  }
}
