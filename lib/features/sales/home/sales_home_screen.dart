import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/online_chip.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// Sales home screen matching `FSCM_Prototype_Prod_v1.1.html` (`DEFS.sales`).
class SalesHomeScreen extends ConsumerWidget {
  const SalesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncServiceProvider);
    final network = ref.watch(networkMonitorProvider);
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
    final waiting = orders.where((o) => o.status == OrderStatus.pending).length;
    final rejected =
        orders.where((o) => o.status == OrderStatus.rejected).length;
    final unsynced = queue
        .where((e) =>
            e.status == SyncStatus.pending || e.status == SyncStatus.syncing)
        .length;
    final overdue = debts.where((d) => d.isOverdue).toList();
    final promoCount = catalog?.runningPromotions().length ?? 0;
    final priorityRetailers =
        (catalog?.retailers ?? const <Retailer>[]).take(3).toList();
    final topProducts =
        (catalog?.products ?? const <Product>[]).take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Xin chào, ${user?.fullName ?? 'Nguyễn Văn An'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              (user?.scopeText.isNotEmpty ?? false)
                  ? user!.scopeText
                  : 'Nhóm Q12-A · Khu vực Quận 12',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: const <Widget>[
          OnlineChip(),
          SizedBox(width: 4),
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: NotificationBellButton(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncServiceProvider.notifier).syncAll(manual: true);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            _SyncCard(
              unsynced: unsynced,
              lastSyncAt: catalog?.lastSyncAt ?? sync.lastSyncAt,
              summary: sync.lastSummary,
              error: sync.lastError,
            ),
            if (Env.useMock)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Giả lập mất mạng (demo)'),
                subtitle:
                    const Text('Bật để tạo đơn offline, tắt để tự đồng bộ'),
                value: network.simulatedOffline,
                onChanged: (v) => ref
                    .read(networkMonitorProvider.notifier)
                    .setSimulatedOffline(v),
              ),
            if (overdue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push(AppRoutes.salesDebts),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF3C3BD)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${overdue.length} khoản công nợ quá hạn – mở danh sách để đi thu',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8F1D14),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.danger,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => context.push(AppRoutes.salesRetailers),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: const Text('+ Tạo đơn hàng mới'),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    label: 'Đơn hôm nay',
                    value: '${todayOrders.length}',
                    valueColor: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Chờ duyệt',
                    value: '$waiting',
                    valueColor: const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Thiếu hàng / từ chối',
                    value: '$rejected',
                    valueColor: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _GridActionCard(
                    icon: Icons.percent,
                    title: 'Khuyến mãi đang chạy',
                    subtitle: '$promoCount chương trình · Tồn & ưu đãi',
                    onTap: () => context.push(AppRoutes.salesPromotions),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GridActionCard(
                    icon: Icons.trending_up,
                    title: 'Doanh số của tôi',
                    subtitle: 'Tháng 9 · tiến độ chỉ tiêu',
                    onTap: () => context.push(AppRoutes.salesKpi),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _GridActionCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Bảng xếp hạng',
                    subtitle: 'Trong nhóm ${user?.salesGroup ?? 'Q12-A'}',
                    onTap: () => context.push(AppRoutes.salesKpi),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GridActionCard(
                    icon: Icons.storefront_outlined,
                    title: 'Khai báo retailer',
                    subtitle: 'Thêm điểm bán mới',
                    onTap: () => context.push(AppRoutes.salesDeclarations),
                  ),
                ),
              ],
            ),
            if (priorityRetailers.isNotEmpty) ...<Widget>[
              SectionTitle(
                'Điểm bán ưu tiên',
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.salesRetailers),
                  child: const Text('Tất cả retailer'),
                ),
              ),
              for (final r in priorityRetailers)
                AppCard(
                  onTap: () => context.push(AppRoutes.salesNewOrder(r.code)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${r.code} · ${r.address}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: r.creditAllowed ? 'Tốt' : 'Trả trước',
                            tone: r.creditAllowed
                                ? StatusTone.success
                                : StatusTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            r.creditAllowed
                                ? 'Công nợ ${r.creditTerm} ngày · ${r.points} điểm'
                                : 'Thanh toán trả trước · ${r.points} điểm',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () =>
                                context.push(AppRoutes.salesNewOrder(r.code)),
                            child: const Text('Tạo đơn'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            if (topProducts.isNotEmpty) ...<Widget>[
              SectionTitle(
                'Bán chạy tháng 9',
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.salesProducts),
                  child: const Text('Bảng giá & tồn'),
                ),
              ),
              AppCard(
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < topProducts.length; i++) ...<Widget>[
                      if (i > 0)
                        const Divider(height: 16, color: Color(0xFFEEF0EC)),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFECEEF1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i == 0
                                    ? const Color(0xFF92400E)
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  topProducts[i].name,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${topProducts[i].sku} · Giá ${Money.format(topProducts[i].basePrice)}/${topProducts[i].pack}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (notes.isNotEmpty) ...<Widget>[
              SectionTitle(
                'Thông báo mới',
                trailing: TextButton(
                  onPressed: () => context.push(AppRoutes.notifications),
                  child: const Text('Tất cả'),
                ),
              ),
              for (final n in notes.take(2))
                AppCard(
                  onTap: () => context.push(AppRoutes.notifications),
                  child: Text(
                    n.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: n.unread ? FontWeight.w600 : FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.unsynced,
    required this.lastSyncAt,
    required this.summary,
    required this.error,
  });

  final int unsynced;
  final DateTime? lastSyncAt;
  final String? summary;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$unsynced đơn chờ đồng bộ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Dữ liệu trên máy lúc ${AppDates.timeDay(lastSyncAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => context.go(AppRoutes.salesSync),
            icon: const Icon(Icons.list_alt, size: 16),
            label: const Text('Mở Đồng bộ'),
          ),
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                summary!,
                style:
                    const TextStyle(color: AppColors.success, fontSize: 12.5),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridActionCard extends StatelessWidget {
  const _GridActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
