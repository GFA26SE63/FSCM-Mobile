import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/shared/widgets/permission_navigation_bar.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// Bottom navigation of the Retailer role: Đơn hàng, Quét QR, Tài khoản.
class RetailerShell extends StatelessWidget {
  const RetailerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: PermissionNavigationBar(
          paths: const [
            '/retailer/orders',
            '/retailer/scan',
            '/retailer/account'
          ],
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
              icon: _ScanIcon(),
              label: 'Quét QR',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}

/// Prototype's emphasised centre scan button: a filled brand circle that
/// sits slightly above the other icons. Presentation only; still a normal
/// destination of the same bar (same route, index and label).
class _ScanIcon extends StatelessWidget {
  const _ScanIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: -6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.qr_code_scanner,
                      size: 20, color: AppColors.onPrimary),
                ),
              ),
            ),
          ],
        ),
      );
}
