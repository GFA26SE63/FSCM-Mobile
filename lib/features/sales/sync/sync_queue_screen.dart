import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/offline_draft_actions.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/price_difference_card.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';
import 'package:fscm_mobile/sync/sync_service.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

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
          title: const Text('Bản nháp trên máy'),
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
              Tab(text: 'Cần xử lý (${counts['todo']})'),
              Tab(text: 'Đang gửi (${counts['doing']})'),
              Tab(text: 'Kết quả (${counts['done']})'),
            ],
          ),
        ),
        body: Column(
          children: [
            // The status header may never push the list off screen: it takes
            // at most 45% of the height and scrolls inside that area.
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const InfoBanner(
                        text: 'Bản nháp chỉ được gửi khi bạn bấm Gửi. '
                            'Đăng nhập, có mạng trở lại và cập nhật '
                            'dữ liệu đồng bộ không tự gửi đơn.',
                      ),
                      AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                        child: Column(
                          children: [
                            KvRow('Dữ liệu trên máy lúc',
                                AppDates.timeDay(sync.lastSyncAt)),
                            KvRow('Bản nháp cần xử lý', '${counts['todo']}'),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: sync.busy
                            ? null
                            : () => ref
                                .read(syncServiceProvider.notifier)
                                .refreshSnapshot(),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          sync.phase == SyncPhase.pulling
                              ? 'Đang cập nhật dữ liệu...'
                              : 'Cập nhật dữ liệu đồng bộ',
                        ),
                      ),
                      if (sync.lastError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        InfoBanner(
                          tone: StatusTone.danger,
                          icon: Icons.error_outline,
                          text: sync.lastError!,
                        ),
                      ],
                      if (sync.lastSummary != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        InfoBanner(
                          tone: StatusTone.success,
                          icon: Icons.check_circle_outline,
                          text: sync.lastSummary!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ),
                ),
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
                            (entry) =>
                                entry.status == SyncStatus.pending ||
                                entry.status == SyncStatus.failed ||
                                entry.status == SyncStatus.needsConfirmation,
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
        title: 'Không có bản nháp trong mục này.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, index) => _DraftCard(
        entry: entries[index],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.entry});

  final OfflineOrder entry;

  @override
  Widget build(BuildContext context) {
    final payload = entry.payload;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Text(entry.localCode, style: AppText.strong),
              StatusChip(label: entry.status.label, tone: entry.status.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          Text('${payload.retailerName} · ${payload.retailerCode}',
              style: AppText.bodyMedium),
          Text(AppDates.timeDay(entry.createdAt.toLocal()),
              style: AppText.mutedSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('${payload.lines.length} sản phẩm · Tạm tính',
                    style: AppText.muted),
              ),
              Text(Money.format(payload.localFinal), style: AppText.strong),
            ],
          ),
          if (entry.serverOrderCode.isNotEmpty)
            Text('Mã máy chủ: ${entry.serverOrderCode}',
                style: AppText.mutedSmall),
          if (entry.status == SyncStatus.synced && entry.finalAmount != null)
            PriceDifferenceCard(
              localAmount: payload.localFinal,
              serverAmount: entry.finalAmount!,
              title: 'Kết quả lúc gửi',
              serverLabel: 'Máy chủ đã trả về',
            ),
          TextButton(
            onPressed: () => context.push(
              AppRoutes.salesOrderDetail(
                entry.localCode,
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
