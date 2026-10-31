import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// Bottom navigation of the Retailer role matching FSCM_Prototype_Prod_v1.1:
/// Đơn hàng, [Quét QR], Tài khoản.
class RetailerShell extends StatelessWidget {
  const RetailerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final current = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _RetailerTabItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Đơn hàng',
                selected: current == 0,
                onTap: () => _go(0),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _go(1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Transform.translate(
                      offset: const Offset(0, -10),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface, width: 4),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x5214655B),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Quét QR',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              current == 1 ? FontWeight.w700 : FontWeight.w600,
                          color: current == 1
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _RetailerTabItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Tài khoản',
                selected: current == 2,
                onTap: () => _go(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetailerTabItem extends StatelessWidget {
  const _RetailerTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(selected ? activeIcon : icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
