import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';

/// Notification list shared by all roles; taps deep-link to the subject.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                _markAll(ref, value.valueOrNull ?? const <AppNotification>[]),
            child: const Text('Đánh dấu đã đọc'),
          ),
        ],
      ),
      body: AsyncBody<List<AppNotification>>(
        value: value,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Chưa có thông báo',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) => _tile(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, AppNotification n) {
    return AppCard(
      color: n.unread ? AppColors.primarySoft : null,
      onTap: () async {
        await ref.read(notificationRepositoryProvider).markRead(n);
        ref.invalidate(notificationsProvider);
        if (!context.mounted) return;
        final target = _target(ref.read(currentUserProvider)?.role, n);
        if (target != null) unawaited(context.push(target));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 10),
            child: Icon(
              Icons.circle,
              size: 9,
              color: n.unread ? AppColors.primary : Colors.transparent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(n.text, style: const TextStyle(height: 1.35)),
                const SizedBox(height: 4),
                Text(
                  AppDates.timeDay(n.createdAt),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAll(WidgetRef ref, List<AppNotification> list) async {
    final repo = ref.read(notificationRepositoryProvider);
    for (final n in list.where((x) => x.unread)) {
      await repo.markRead(n);
    }
    ref.invalidate(notificationsProvider);
  }

  /// Deep link for a notification, per role.
  String? _target(UserRole? role, AppNotification n) {
    switch (role) {
      case UserRole.sales:
        if (n.kind == 'debt') return AppRoutes.salesDebts;
        if (n.orderCode.isNotEmpty) {
          return AppRoutes.salesOrderDetail(n.orderCode);
        }
        return null;
      case UserRole.warehouseKeeper:
        if (n.orderCode.isEmpty) return null;
        if (n.kind == 'picking') return AppRoutes.wkPickingDetail(n.orderCode);
        if (n.kind == 'label') return AppRoutes.wkLabel(n.orderCode);
        if (n.kind == 'transfer') {
          return AppRoutes.wkTransferDetail(n.orderCode);
        }
        return null;
      case UserRole.retailer:
        if (n.orderCode.isNotEmpty) return AppRoutes.rtOrderDetail(n.orderCode);
        return null;
      default:
        return null;
    }
  }
}
