import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/features/sales/presentation/screens/insights_screens.dart';
import 'package:fmcg/features/sales/presentation/screens/orders_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SalesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FscmCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE3F0EC),
                  child: Text(
                    'NA',
                    style: TextStyle(
                      color: FscmColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nguyễn Văn An',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Sales Representative · SR-0018',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: FscmColors.muted,
                        ),
                      ),
                      Text(
                        'Nhóm Q12-A · Quận 12',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: FscmColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FscmCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    controller.isOnline ? 'Đang online' : 'Đang offline',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Dữ liệu gần nhất ${controller.lastSync}'),
                  secondary: Icon(
                    controller.isOnline ? Icons.wifi : Icons.wifi_off,
                    color: FscmColors.primary,
                  ),
                  value: controller.isOnline,
                  onChanged: (_) => controller.toggleConnectivity(),
                ),
                const Divider(height: 1),
                _AccountTile(
                  icon: Icons.notifications_outlined,
                  title: 'Thông báo',
                  trailing: '${controller.unreadNotificationCount}',
                  page: const NotificationsScreen(),
                ),
                const Divider(height: 1),
                const _AccountTile(
                  icon: Icons.bar_chart,
                  title: 'Doanh số và KPI',
                  page: SalesDashboardScreen(),
                ),
                const Divider(height: 1),
                const _AccountTile(
                  icon: Icons.emoji_events_outlined,
                  title: 'Bảng xếp hạng',
                  page: RankingScreen(),
                ),
                const Divider(height: 1),
                const _AccountTile(
                  icon: Icons.add_business_outlined,
                  title: 'Retailer đã khai báo',
                  page: RetailerLeadsScreen(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const FscmCard(
            child: Row(
              children: [
                Icon(Icons.security_outlined, color: FscmColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phạm vi truy cập',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Retailer và đơn hàng thuộc nhóm Q12-A',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: FscmColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Đơn chưa đồng bộ vẫn được giữ trên thiết bị này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      SalesScope.of(context, listen: false).logout();
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.page,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget page;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: FscmColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            Badge(label: Text(trailing!)),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }
}
