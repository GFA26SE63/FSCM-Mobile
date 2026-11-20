import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
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
    final stats = ref.watch(salesOrderStatsProvider).valueOrNull ??
        const SalesOrderStats();
    final queue = ref.watch(offlineQueueProvider).valueOrNull ?? const [];
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final debts =
        ref.watch(receivablesProvider).valueOrNull ?? const <Receivable>[];
    final notes = ref.watch(notificationsProvider).valueOrNull?.items ??
        const <AppNotification>[];

    final waiting = stats.waiting;
    final rejected = stats.rejectedToday;
    final delivering = stats.delivering;
    final kpi = ref.watch(salesKpiProvider('month'));
    final kpiEntry = kpi.valueOrNull?.entries.isEmpty ?? true
        ? null
        : kpi.valueOrNull!.entries.first;
    final unsynced = queue.where((e) => e.status.isUnsent).length;
    final overdue = debts.where((d) => d.isOverdue).toList();
    final promoCount = catalog?.runningPromotions().length ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Xin chào, ${user?.fullName ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.pageTitle.copyWith(color: AppColors.text),
            ),
            if ((user?.scopeText ?? '').isNotEmpty)
              Text(
                user!.scopeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mutedSmall,
              ),
          ],
        ),
        actions: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: const FittedBox(fit: BoxFit.scaleDown, child: OnlineChip()),
          ),
          const SizedBox(width: AppSpacing.xs),
          const NotificationBellButton(),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesKpiProvider('month'));
          await ref.read(syncServiceProvider.notifier).refreshSnapshot();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            _SyncCard(
                unsynced: unsynced,
                busy: sync.busy,
                lastSyncAt: catalog?.lastSyncAt ?? sync.lastSyncAt,
                summary: sync.lastSummary,
                error: sync.lastError),
            if (overdue.isNotEmpty)
              InkWell(
                borderRadius: AppRadius.controlAll,
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
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: AppText.button.copyWith(fontSize: 16)),
              onPressed: () => context.push(AppRoutes.salesRetailers),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Tạo đơn hàng mới'),
            ),
            const SectionTitle('Đơn hôm nay'),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                      child: _Stat(
                          label: 'Đã tạo', value: '${stats.createdToday}')),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                      child: _Stat(
                          label: 'Đang chờ xử lý',
                          value: '$waiting',
                          tone: StatusTone.info)),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                      child: _Stat(
                          label: 'Bị từ chối / hủy',
                          value: '$rejected',
                          tone: StatusTone.danger)),
                ],
              ),
            ),
            const SectionTitle('Công việc'),
            _ShortcutGrid(shortcuts: <_ShortcutData>[
              _ShortcutData(
                  icon: Icons.local_offer_outlined,
                  label: 'Khuyến mãi đang chạy',
                  note: '$promoCount chương trình',
                  route: AppRoutes.salesPromotions),
              const _ShortcutData(
                  icon: Icons.inventory_2_outlined,
                  label: 'Sản phẩm & tồn khả dụng',
                  route: AppRoutes.salesProducts),
              const _ShortcutData(
                  icon: Icons.leaderboard_outlined,
                  label: 'Doanh số & bảng xếp hạng',
                  route: AppRoutes.salesKpi),
              _ShortcutData(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Công nợ cần thu',
                  note: overdue.isEmpty ? null : '${overdue.length} quá hạn',
                  noteTone: StatusTone.danger,
                  route: AppRoutes.salesDebts),
              const _ShortcutData(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Khai báo điểm bán',
                  route: AppRoutes.salesDeclarations),
            ]),
            const SectionTitle('Tháng này'),
            AppCard(
              key: const Key('sales_home_kpi'),
              onTap: () => context.push(AppRoutes.salesKpi),
              child: kpi.isLoading
                  ? const Text('Đang tải doanh số tháng...')
                  : kpiEntry == null
                      ? const Text(
                          'Chưa có chỉ tiêu KPI hoặc doanh số ghi nhận trong tháng.',
                          style: AppText.muted)
                      : Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: AppSpacing.s10,
                          spacing: AppSpacing.lg,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('Doanh số ghi nhận',
                                    style: AppText.mutedSmall),
                                Text(
                                    Money.format(
                                        kpiEntry.recognizedRevenue.round()),
                                    style: AppText.display
                                        .copyWith(color: AppColors.text)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text('Hoàn thành KPI',
                                    style: AppText.mutedSmall),
                                Text(
                                    '${(kpiEntry.overallCompletionRate * 100).toStringAsFixed(1)}%',
                                    style: AppText.display.copyWith(
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
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                        child: Text('Đơn đang giao', style: AppText.cardTitle)),
                    Text('$delivering', style: AppText.muted),
                    const SizedBox(width: AppSpacing.s6),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
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
                      style: AppText.bodyMedium.copyWith(
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

/// Sync status card (prototype: icon tile + count + last sync + action).
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.controlAll),
                child: const Icon(Icons.sync, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      unsynced == 0
                          ? 'Không có đơn chờ đồng bộ'
                          : '$unsynced đơn chờ đồng bộ',
                      style: AppText.cardTitle,
                    ),
                    Text(
                      'Dữ liệu cập nhật ${AppDates.timeDay(lastSyncAt)}',
                      style: AppText.mutedSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.touch)),
                  onPressed: () => context.go(AppRoutes.salesSync),
                  child: const Text('Mở hàng đợi', textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.touch)),
                  onPressed: busy
                      ? null
                      : () => ref
                          .read(syncServiceProvider.notifier)
                          .refreshSnapshot(),
                  child: Text(busy ? 'Đang đồng bộ...' : 'Đồng bộ',
                      textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          if (summary != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(summary!,
                style: AppText.bodyMedium.copyWith(color: AppColors.success)),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(error!,
                style: AppText.bodySmall.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

/// White stat card: small label above a large coloured number.
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
    final color = tone == StatusTone.neutral
        ? AppColors.text
        : AppColors.tone(tone).foreground;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppText.mutedSmall.copyWith(fontSize: 12)),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: AppText.display.copyWith(fontSize: 24, color: color)),
        ],
      ),
    );
  }
}

class _ShortcutData {
  const _ShortcutData({
    required this.icon,
    required this.label,
    required this.route,
    this.note,
    this.noteTone,
  });

  final IconData icon;
  final String label;
  final String route;
  final String? note;
  final StatusTone? noteTone;
}

/// Two-column grid of shortcut cards (prototype: icon above label).
class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.shortcuts});

  final List<_ShortcutData> shortcuts;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < shortcuts.length; i += 2) {
      final second = i + 1 < shortcuts.length ? shortcuts[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _ShortcutCard(shortcuts[i])),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                  child: second == null
                      ? const SizedBox.shrink()
                      : _ShortcutCard(second)),
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard(this.data);

  final _ShortcutData data;

  @override
  Widget build(BuildContext context) {
    final noteColor = data.noteTone == null
        ? AppColors.textMuted
        : AppColors.tone(data.noteTone!).foreground;
    return AppCard(
      margin: EdgeInsets.zero,
      onTap: () => context.push(data.route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(data.icon, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(data.label, style: AppText.cardTitle.copyWith(fontSize: 14)),
            if (data.note != null)
              Text(data.note!,
                  style: AppText.mutedSmall.copyWith(color: noteColor)),
          ],
        ),
      ),
    );
  }
}
