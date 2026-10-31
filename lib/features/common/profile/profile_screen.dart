import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';

/// Role-specific shortcut shown on the profile screen.
class ProfileAction {
  const ProfileAction({
    required this.label,
    required this.icon,
    required this.route,
    this.trailingText,
  });
  final String label;
  final IconData icon;
  final String route;
  final String? trailingText;
}

/// "Tài khoản": user header, role shortcuts, change password and logout
/// matching FSCM_Prototype_Prod_v1.1.html.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.actions = const <ProfileAction>[]});

  final List<ProfileAction> actions;

  Color _avatarColorFor(UserRole role) {
    switch (role) {
      case UserRole.warehouseKeeper:
        return const Color(0xFF8A4B0C);
      case UserRole.retailer:
        return const Color(0xFF1F4E79);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final contactText = <String>[
      if (user != null && user.email.isNotEmpty) user.email,
      if (user != null && user.phone.isNotEmpty) user.phone,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
        actions: const <Widget>[NotificationBellButton()],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border:
                        Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _avatarColorFor(user.role),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              contactText.isNotEmpty
                                  ? '${user.role.label} · $contactText'
                                  : user.role.label,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (user.scopeText.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                user.scopeText,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                for (final a in actions)
                  _RowLink(
                    icon: a.icon,
                    label: a.label,
                    trailingText: a.trailingText,
                    onTap: () => context.push(a.route),
                  ),
                const SizedBox(height: 10),
                if (user.role == UserRole.retailer)
                  _RowLink(
                    icon: Icons.lock_outline,
                    label: 'Đổi mật khẩu',
                    onTap: () => _showChangePasswordSheet(context),
                  ),
                _RowLink(
                  key: const Key('btn_logout'),
                  icon: Icons.logout,
                  label: 'Đăng xuất',
                  textColor: AppColors.danger,
                  showChevron: false,
                  onTap: () => _logout(context, ref),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'FSCM Mobile 0.1.0 · FA26SE083',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _showChangePasswordSheet(BuildContext context) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final cfCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final ok = oldCtrl.text.isNotEmpty &&
                newCtrl.text.length >= 8 &&
                newCtrl.text == cfCtrl.text;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5D1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Đổi mật khẩu',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mật khẩu hiện tại',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldCtrl,
                    obscureText: true,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Mật khẩu mới (tối thiểu 8 ký tự, chữ + số)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nhập lại mật khẩu mới',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: cfCtrl,
                    obscureText: true,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: ok
                              ? () {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã đổi mật khẩu'),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Lưu mật khẩu'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    int unsynced = 0;
    try {
      final queue = ref.read(offlineQueueProvider).valueOrNull ?? const [];
      unsynced = queue.where((e) => e.status == SyncStatus.pending).length;
    } catch (_) {}

    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: unsynced > 0
          ? 'Còn $unsynced đơn chưa đồng bộ. Đơn vẫn được giữ trên máy và gửi khi bạn đăng nhập lại có mạng.'
          : 'Bạn sẽ cần đăng nhập lại để tiếp tục.',
      confirmLabel: 'Đăng xuất',
    );
    if (!ok) return;

    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      if (context.mounted) {
        try {
          context.go(AppRoutes.login);
        } catch (_) {}
      }
    }
  }
}

class _RowLink extends StatelessWidget {
  const _RowLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.textColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;
  final Color? textColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.text;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFEEF0EC)),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
