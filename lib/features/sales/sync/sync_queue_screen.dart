import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/online_chip.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// "Đồng bộ": offline order queue matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.sales` QUEUE).
class SyncQueueScreen extends ConsumerWidget {
  const SyncQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(offlineQueueProvider);
    final sync = ref.watch(syncServiceProvider);
    final online = ref.watch(networkMonitorProvider).online;
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final entries = queue.valueOrNull ?? const <OfflineOrder>[];
    final counts = SyncQueueLogic.tabCounts(entries);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Đồng bộ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                'Đơn lập khi ngoại tuyến',
                style: TextStyle(
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
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: <Widget>[
              Tab(text: 'Chưa gửi (${counts['todo']})'),
              Tab(text: 'Đang gửi (${counts['doing']})'),
              Tab(text: 'Đã gửi (${counts['done']})'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const KvRow(
                      'Gửi đơn nháp',
                      'Thủ công – bấm Gửi khi có mạng',
                    ),
                    KvRow(
                      'Dữ liệu trên máy lúc',
                      AppDates.timeDay(catalog?.lastSyncAt ?? sync.lastSyncAt),
                    ),
                    KvRow('Đơn chờ đồng bộ', '${counts['todo']}'),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: (!online || sync.busy)
                          ? null
                          : () => ref
                              .read(syncServiceProvider.notifier)
                              .syncAll(manual: true),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(
                        sync.busy
                            ? 'Đang đồng bộ...'
                            : 'Gửi tất cả (${counts['todo']})',
                      ),
                    ),
                    if (!online)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Đang ngoại tuyến – kết nối mạng để gửi đơn lên hệ thống.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    if (sync.lastError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          sync.lastError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    if (sync.lastSummary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          sync.lastSummary!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AsyncBody<List<OfflineOrder>>(
                value: queue,
                onRetry: () => ref.invalidate(offlineQueueProvider),
                builder: (list) => TabBarView(
                  children: <Widget>[
                    _list(
                      context,
                      list
                          .where((e) => e.status == SyncStatus.pending)
                          .toList(),
                      'Không có đơn chờ gửi.',
                    ),
                    _list(
                      context,
                      list
                          .where((e) => e.status == SyncStatus.syncing)
                          .toList(),
                      'Không có đơn đang gửi.',
                    ),
                    _list(
                      context,
                      list
                          .where((e) =>
                              e.status == SyncStatus.synced ||
                              e.status == SyncStatus.rejected)
                          .toList(),
                      'Chưa có đơn nào đã gửi.',
                      done: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<OfflineOrder> items, String empty,
      {bool done = false}) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.cloud_done_outlined, title: empty);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (done)
          const InfoBanner(
            text:
                'Thứ tự xử lý theo thời điểm máy chủ nhận đơn; khuyến mãi được tính lại tại thời điểm đó.',
          ),
        for (final e in items) _SyncTile(entry: e),
      ],
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.entry});

  final OfflineOrder entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final p = e.payload;
    final code = e.status == SyncStatus.synced && e.serverOrderCode.isNotEmpty
        ? e.serverOrderCode
        : e.localCode;
    return AppCard(
      onTap: () => context.push(AppRoutes.salesOrderDetail(code)),
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
                      e.localCode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${p.retailerName} · Lập lúc ${AppDates.timeDay(e.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: e.status.label, tone: e.status.tone),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${p.lines.length} mặt hàng · dự kiến',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                Money.format(p.localFinal),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (e.status == SyncStatus.synced) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Mã đơn chính thức: ${e.serverOrderCode}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (e.promoChanged)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: StatusChip(
                  label: 'KM thay đổi khi đồng bộ',
                  tone: StatusTone.warning,
                ),
              ),
          ],
          if (e.status == SyncStatus.rejected)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                e.error,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          if (e.status == SyncStatus.pending && e.retryCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Thử gửi lần ${e.retryCount}${e.error.isEmpty ? '' : ' · ${e.error}'}',
                style:
                    const TextStyle(color: AppColors.warning, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
