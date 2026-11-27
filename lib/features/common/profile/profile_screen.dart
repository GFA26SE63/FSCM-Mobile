import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/core/auth/screen_permissions.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'widgets/profile_identity_card.dart';

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
    final visibleActions = <String, ProfileAction>{
      for (final action in actions)
        if (canAccessMobilePath(user, action.route)) action.route: action,
      if (user != null)
        for (final entry in mobileDestinations.entries)
          if (canAccessMobilePath(user, entry.key) &&
              !actions.any((action) => action.route == entry.key))
            entry.key: ProfileAction(
                label: entry.value,
                icon: Icons.apps_outlined,
                route: entry.key),
    }.values;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                ProfileIdentityCard(user: user),
                if (user.hasPermission('mobile-rt-payments') &&
                    canAccessMobilePath(user, AppRoutes.rtPayments))
                  _CreditProfileCard(),
                for (final a in visibleActions)
                  AppCard(
                    onTap: () => context.push(a.route),
                    child: Row(
                      children: <Widget>[
                        Icon(a.icon, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            a.label,
                            style: AppText.cardTitle
                                .copyWith(color: AppColors.text),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('btn_logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(
                        color: AppColors.dangerBorder, width: 1.5),
                  ),
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    'FSCM Mobile 0.1.0 · FA26SE083',
                    style: AppText.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    int unsynced = 0;
    try {
      final queue = ref.read(offlineQueueProvider).valueOrNull ?? const [];
      unsynced = queue.where((e) => e.status.isUnsent).length;
    } catch (_) {}

    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: unsynced > 0
          ? 'Còn $unsynced đơn chưa gửi xong. Đơn vẫn được giữ trên máy; đăng nhập lại đúng tài khoản và bấm Gửi để tiếp tục.'
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

class _CreditProfileCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credit = ref.watch(ownRetailerCreditProvider);
    return AppCard(
      child: credit.when(
        loading: () => const ListTile(
            title: Text('Công nợ'),
            subtitle: Text('Đang tải hạn mức và kỳ hạn…')),
        error: (_, __) => const ListTile(
            title: Text('Công nợ'),
            subtitle: Text('Chưa tải được hồ sơ công nợ.')),
        data: (retailer) => ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.primary),
          title: const Text('Hạn mức & kỳ hạn công nợ'),
          subtitle: Text(
              'Hạn mức: ${Money.format(retailer.creditLimit)}\nKỳ hạn: ${retailer.creditTerm} ngày, tính từ ngày nhận đủ hàng.'),
        ),
      ),
    );
  }
}
