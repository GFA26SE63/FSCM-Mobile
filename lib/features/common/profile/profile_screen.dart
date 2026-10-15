import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';

/// Role-specific shortcut shown on the profile screen.
class ProfileAction {
  const ProfileAction(
      {required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
}

/// "Tài khoản": user card, role shortcuts and logout (shared by all roles).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.actions = const <ProfileAction>[]});

  final List<ProfileAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                AppCard(
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${user.role.label} · ${user.scopeText}',
                              style:
                                  const TextStyle(color: AppColors.textMuted),
                            ),
                            Text(user.phone,
                                style: const TextStyle(
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final a in actions)
                  AppCard(
                    onTap: () => context.push(a.route),
                    child: Row(
                      children: <Widget>[
                        Icon(a.icon, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            a.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'FSCM Mobile 0.1.0 · FA26SE083',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final queue = ref.read(offlineQueueProvider).valueOrNull ?? const [];
    final unsynced = queue.where((e) => e.status == SyncStatus.pending).length;
    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: unsynced > 0
          ? 'Còn $unsynced đơn chưa đồng bộ. Đơn vẫn được giữ trên máy và gửi khi bạn đăng nhập lại có mạng.'
          : 'Bạn sẽ cần đăng nhập lại để tiếp tục.',
      confirmLabel: 'Đăng xuất',
    );
    if (!ok) return;
    await ref.read(authControllerProvider.notifier).logout();
  }
}
