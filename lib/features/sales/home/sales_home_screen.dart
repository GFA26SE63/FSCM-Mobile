import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/online_chip.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// Sales home: today's numbers, sync status, shortcuts.
class SalesHomeScreen extends ConsumerWidget {
  const SalesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncServiceProvider);
    final orders =
        ref.watch(ordersProvider).valueOrNull?.orders ?? const <Order>[];
    final queue = ref.watch(offlineQueueProvider).valueOrNull ?? const [];
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final debts =
        ref.watch(receivablesProvider).valueOrNull ?? const <Receivable>[];
    final notes = ref.watch(notificationsProvider).valueOrNull ?? const [];

    final today = AppClock.today();
    final todayOrders =
        orders.where((o) => AppDates.isSameDay(o.createdAt, today)).toList();
    // Every number under "Đơn hôm nay" is about today's orders only.
    final waiting = todayOrders
        .where((o) =>
            o.status == OrderStatus.allocating ||
            o.status == OrderStatus.quoted ||
            o.status == OrderStatus.paymentPending)
        .length;
    final rejected =
        todayOrders.where((o) => o.status.isRejectedOrCancelled).length;
    final delivering =
        orders.where((o) => o.status == OrderStatus.delivering).length;
    final kpi = ref.watch(salesKpiProvider('month'));
    final kpiEntry = kpi.valueOrNull?.entries.isEmpty ?? true
        ? null
        : kpi.valueOrNull!.entries.first;
    final unsynced = queue.where((e) => e.status.isUnsent).length;
    final overdue = debts.where((d) => d.isOverdue).toList();
    final promoCount = catalog?.runningPromotions().length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: const <Widget>[
          Padding(
              padding: EdgeInsets.only(right: 4),
              child: NotificationBellButton())
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesKpiProvider('month'));
          await ref.read(syncServiceProvider.notifier).refreshSnapshot();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Xin chào, ${user?.fullName ?? ''}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(user?.scopeText ?? '',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            _SyncCard(
                unsynced: unsynced,
                busy: sync.busy,
                lastSyncAt: catalog?.lastSyncAt ?? sync.lastSyncAt,
                summary: sync.lastSummary,
                error: sync.lastError),
            if (overdue.isNotEmpty)
              InkWell(
                onTap: () => context.push(AppRoutes.salesDebts),
                child: InfoBanner(
                  tone: StatusTone.danger,
                  icon: Icons.warning_amber_rounded,
                  title: 'Có ${overdue.length} khoản công nợ quá hạn',
                  text:
                      'Cần thu ${Money.format(overdue.fold<int>(0, (s, d) => s + d.amount))} - mở danh sách để đi thu.',
                ),
              ),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.salesRetailers),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tạo đơn hàng mới'),
            ),
            const SectionTitle('Đơn hôm nay'),
            Row(
              children: <Widget>[
                Expanded(
                    child:
                        _Stat(label: 'Đã tạo', value: '${todayOrders.length}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: 'Đang chờ xử lý',
                        value: '$waiting',
                        tone: StatusTone.info)),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: 'Bị từ chối / hủy',
                        value: '$rejected',
                        tone: StatusTone.danger)),
              ],
            ),
            const SectionTitle('Tháng này'),
            AppCard(
              key: const Key('sales_home_kpi'),
              onTap: () => context.push(AppRoutes.salesKpi),
              child: kpi.isLoading
                  ? const Text('Đang tải doanh số tháng...')
                  : kpiEntry == null
                      ? const Text(
                          'Chưa có chỉ tiêu KPI hoặc doanh số ghi nhận trong tháng.',
                          style: TextStyle(color: AppColors.textMuted))
                      : Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text('Doanh số ghi nhận',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12.5)),
                                  Text(
                                      Money.format(
                                          kpiEntry.recognizedRevenue.round()),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                const Text('Hoàn thành KPI',
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12.5)),
                                Text(
                                    '${(kpiEntry.overallCompletionRate * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            kpiEntry.overallCompletionRate >= 1
                                                ? AppColors.success
                                                : AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
            ),
            if (delivering > 0)
              AppCard(
                onTap: () => context.go(AppRoutes.salesOrders),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.local_shipping_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Đơn đang giao',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    Text('$delivering',
                        style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            const SectionTitle('Công việc'),
            _Shortcut(
                icon: Icons.local_offer_outlined,
                label: 'Khuyến mãi đang chạy',
                trailing: '$promoCount',
                route: AppRoutes.salesPromotions),
            const _Shortcut(
                icon: Icons.inventory_2_outlined,
                label: 'Sản phẩm & tồn khả dụng',
                route: AppRoutes.salesProducts),
            const _Shortcut(
                icon: Icons.leaderboard_outlined,
                label: 'Doanh số & bảng xếp hạng',
                route: AppRoutes.salesKpi),
            _Shortcut(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Công nợ cần thu',
                trailing: overdue.isEmpty ? null : '${overdue.length} quá hạn',
                route: AppRoutes.salesDebts),
            const _Shortcut(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Khai báo retailer',
                route: AppRoutes.salesDeclarations),
            if (notes.isNotEmpty) ...<Widget>[
              SectionTitle(
                'Thông báo mới',
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.notifications),
                  child: const Text('Xem tất cả'),
                ),
              ),
              for (final n in notes.take(3))
                AppCard(
                  onTap: () => context.push(AppRoutes.notifications),
                  child: Text(n.text,
                      style: TextStyle(
                          fontWeight:
                              n.unread ? FontWeight.w700 : FontWeight.w400,
                          height: 1.35)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard({
    required this.unsynced,
    required this.busy,
    required this.lastSyncAt,
    required this.summary,
    required this.error,
  });

  final int unsynced;
  final bool busy;
  final DateTime? lastSyncAt;
  final String? summary;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const OnlineChip(),
              const Spacer(),
              Text(
                'Dữ liệu cập nhật ${AppDates.timeDay(lastSyncAt)}',
                style:
                    const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  unsynced == 0
                      ? 'Không có đơn chờ đồng bộ'
                      : '$unsynced đơn chờ đồng bộ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.salesSync),
                child: const Text('Mở hàng đợi'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                onPressed: busy
                    ? null
                    : () => ref
                        .read(syncServiceProvider.notifier)
                        .refreshSnapshot(),
                child: Text(busy ? 'Đang đồng bộ...' : 'Đồng bộ'),
              ),
            ],
          ),
          if (summary != null)
            Text(summary!, style: const TextStyle(color: AppColors.success)),
          if (error != null)
            Text(error!,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label,
      required this.value,
      this.tone = StatusTone.neutral});

  final String label;
  final String value;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.tone(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: c.foreground)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: c.foreground)),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(
      {required this.icon,
      required this.label,
      required this.route,
      this.trailing});

  final IconData icon;
  final String label;
  final String route;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(route),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(trailing!,
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
