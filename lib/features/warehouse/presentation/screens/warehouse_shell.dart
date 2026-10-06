import 'package:flutter/material.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_home_screen.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_picking_screens.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_receive_screen.dart';
import 'package:fmcg/features/warehouse/presentation/screens/warehouse_services_screens.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_scope.dart';

class WarehouseShell extends StatelessWidget {
  const WarehouseShell({super.key});

  static const _pages = <Widget>[
    WarehouseHomeScreen(),
    WarehousePickingsScreen(),
    WarehouseScannerScreen(),
    WarehouseReceiveScreen(),
    WarehouseAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    return Scaffold(
      body: IndexedStack(index: controller.currentTab, children: _pages),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: controller.currentTab,
        onDestinationSelected: controller.setTab,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: controller.waitingCount > 0,
              label: Text('${controller.waitingCount}'),
              child: const Icon(Icons.assignment_outlined),
            ),
            selectedIcon: const Icon(Icons.assignment),
            label: 'Picking',
          ),
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Quét QR',
          ),
          const NavigationDestination(
            icon: Icon(Icons.move_to_inbox_outlined),
            selectedIcon: Icon(Icons.move_to_inbox),
            label: 'Nhập kho',
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
