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
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
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
            onPressed: () => _markAll(ref),
            child: const Text('Đánh dấu đã đọc'),
          ),
        ],
      ),
      body: AsyncBody<NotificationsState>(
        value: value,
        onRetry: () => _refresh(ref),
        builder: (state) {
          final list = state.items;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Chưa có thông báo',
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, i) => i < list.length
                  ? _tile(context, ref, list[i])
                  : _loadMore(ref, state),
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
        await ref.read(notificationsProvider.notifier).markRead(n);
        if (!context.mounted) return;
        final target = _target(ref.read(currentUserProvider)?.role, n);
        if (target != null) unawaited(context.push(target));
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.s6, right: AppSpacing.s10),
            child: Icon(
              Icons.circle,
              size: 8,
              color: n.unread ? AppColors.primary : Colors.transparent,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (n.title.isNotEmpty) ...<Widget>[
                  Text(n.title,
                      style: AppText.cardTitle.copyWith(
                          fontWeight:
                              n.unread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.text)),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(n.text,
                    style: AppText.bodyMedium
                        .copyWith(height: 1.35, color: AppColors.text)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppDates.timeDay(n.createdAt),
                  style: AppText.caption.copyWith(
                      fontWeight: FontWeight.w400, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAll(WidgetRef ref) =>
      ref.read(notificationsProvider.notifier).markAllRead();

  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(notificationBadgeProvider);
    return ref.read(notificationsProvider.notifier).refresh();
  }

  Widget _loadMore(WidgetRef ref, NotificationsState state) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }
    return Column(
      children: <Widget>[
        if (state.moreError != null)
          Text(state.moreError!,
              style: AppText.bodyMedium.copyWith(color: AppColors.textMuted)),
        TextButton(
          onPressed: () => ref.read(notificationsProvider.notifier).loadMore(),
          child: const Text('Tải thêm'),
        ),
      ],
    );
  }

  /// Deep link for a notification, per role.
  String? _target(UserRole? role, AppNotification n) {
    final serverTarget = _serverDeepLink(role, n.deepLink);
    if (serverTarget != null) return serverTarget;
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
        return null;
      case UserRole.retailer:
        if (n.orderCode.isNotEmpty) return AppRoutes.rtOrderDetail(n.orderCode);
        return null;
      default:
        return null;
    }
  }

  String? _serverDeepLink(UserRole? role, String link) {
    if (link.isEmpty) return null;
    if (link == '/retailer/complaints') return AppRoutes.rtComplaints;

    const retailerOrders = '/retailer/orders/';
    if (link.startsWith(retailerOrders)) {
      final id = link.substring(retailerOrders.length);
      return role == UserRole.retailer && id.isNotEmpty
          ? AppRoutes.rtOrderDetail(Uri.encodeComponent(id))
          : null;
    }

    const orders = '/orders/';
    if (link.startsWith(orders)) {
      final id = link.substring(orders.length);
      if (id.isEmpty) return null;
      if (role == UserRole.retailer) {
        return AppRoutes.rtOrderDetail(Uri.encodeComponent(id));
      }
      if (role == UserRole.sales) {
        return AppRoutes.salesOrderDetail(id);
      }
    }
    return null;
  }
}
