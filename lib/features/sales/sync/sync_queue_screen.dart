import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/offline_draft_actions.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

class SyncQueueScreen extends ConsumerWidget {
  const SyncQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(offlineQueueProvider);
    final sync = ref.watch(syncServiceProvider);
    final entries = queue.valueOrNull ?? const <OfflineOrder>[];
    final counts = SyncQueueLogic.tabCounts(entries);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Draft trên máy'),
          actions: [
            IconButton(
              tooltip: 'Tải lại hàng đợi',
              onPressed: () => ref.invalidate(offlineQueueProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Chưa gửi (${counts['todo']})'),
              Tab(text: 'Đang gửi (${counts['doing']})'),
              Tab(text: 'Kết quả (${counts['done']})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    text: 'Draft chỉ được gửi khi bạn bấm Gửi. '
                        'Đăng nhập, có mạng trở lại và cập nhật '
                        'snapshot không tự gửi đơn.',
                  ),
                  OutlinedButton.icon(
                    onPressed: sync.busy
                        ? null
                        : () => ref
                            .read(syncServiceProvider.notifier)
                            .refreshSnapshot(),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      sync.phase == SyncPhase.pulling
                          ? 'Đang cập nhật dữ liệu...'
                          : 'Cập nhật snapshot',
                    ),
                  ),
                  if (sync.lastError != null)
                    Text(
                      sync.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (sync.lastSummary != null) Text(sync.lastSummary!),
                ],
              ),
            ),
            Expanded(
              child: AsyncBody<List<OfflineOrder>>(
                value: queue,
                onRetry: () => ref.invalidate(offlineQueueProvider),
                builder: (list) => TabBarView(
                  children: [
                    _DraftList(
                      entries: list
                          .where(
                            (entry) => entry.status == SyncStatus.pending,
                          )
                          .toList(),
                    ),
                    _DraftList(
                      entries: list
                          .where(
                            (entry) => entry.status == SyncStatus.syncing,
                          )
                          .toList(),
                    ),
                    _DraftList(
                      entries: list
                          .where(
                            (entry) =>
                                entry.status == SyncStatus.synced ||
                                entry.status == SyncStatus.rejected,
                          )
                          .toList(),
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
}

class _DraftList extends StatelessWidget {
  const _DraftList({required this.entries});

  final List<OfflineOrder> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Không có draft trong mục này.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _DraftCard(
        entry: entries[index],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.entry});

  final OfflineOrder entry;

  String get _status {
    switch (entry.status) {
      case SyncStatus.pending:
        return entry.error.isEmpty ? 'Bản nháp' : 'Chưa gửi được';
      case SyncStatus.syncing:
        return 'Đang gửi / chờ kết quả';
      case SyncStatus.synced:
        return 'Đã gửi';
      case SyncStatus.rejected:
        return 'Kết quả từ chối cũ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = entry.payload;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            entry.localCode,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(_status),
          const SizedBox(height: 6),
          Text('${payload.retailerName} · ${payload.retailerCode}'),
          Text(
            AppDates.timeDay(entry.createdAt.toLocal()),
          ),
          Text(
            '${payload.lines.length} sản phẩm · '
            'Tạm tính ${Money.format(payload.localFinal)}',
          ),
          if (entry.serverOrderCode.isNotEmpty)
            Text('Mã server: ${entry.serverOrderCode}'),
          TextButton(
            onPressed: () => context.push(
              AppRoutes.salesOrderDetail(
                entry.status == SyncStatus.synced &&
                        entry.serverOrderCode.isNotEmpty
                    ? entry.serverOrderCode
                    : entry.localCode,
              ),
            ),
            child: const Text('Xem chi tiết'),
          ),
          OfflineDraftActions(entry: entry),
        ],
      ),
    );
  }
}
