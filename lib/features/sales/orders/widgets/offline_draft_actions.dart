import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/orders/draft_edit_screen.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/sync/sync_queue_logic.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

class OfflineDraftActions extends ConsumerWidget {
  const OfflineDraftActions({
    super.key,
    required this.entry,
    this.onDeleted,
  });

  final OfflineOrder entry;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncServiceProvider);
    final online = ref.watch(networkMonitorProvider).online;

    final editable = SyncQueueLogic.canEdit(entry);
    final sendable = SyncQueueLogic.canSend(
      entry,
      AppClock.now(),
    );
    final completed = entry.status == SyncStatus.synced ||
        entry.status == SyncStatus.rejected;

    if (completed) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry.error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              entry.error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        FilledButton.icon(
          onPressed: !online || sync.busy || !sendable
              ? null
              : () => _send(context, ref),
          icon: const Icon(Icons.send_outlined),
          label: Text(
            sync.phase == SyncPhase.pushing
                ? 'Đang gửi...'
                : entry.lastAttemptAt == null
                    ? 'Gửi đơn'
                    : 'Gửi lại cùng yêu cầu',
          ),
        ),
        if (!online)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Đang offline. Có mạng trở lại vẫn cần bấm Gửi.',
            ),
          ),
        if (entry.status == SyncStatus.syncing && !sendable)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Lần gửi trước chưa có kết quả. Nếu ứng dụng bị ngắt, '
              'chờ 2 phút rồi tải lại để thử gửi cùng yêu cầu.',
            ),
          ),
        if (editable)
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: sync.busy
                    ? null
                    : () async {
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => DraftEditScreen(
                              entry: entry,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Sửa draft'),
              ),
              TextButton.icon(
                onPressed: sync.busy ? null : () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa draft'),
              ),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Draft đã bắt đầu gửi. Nội dung được giữ nguyên '
              'để gửi lại bằng cùng key.',
            ),
          ),
      ],
    );
  }

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Gửi ${entry.localCode}?',
      message: 'Gửi riêng draft này lên hệ thống. '
          'Backend sẽ kiểm tra lại giá, MLOR và phạm vi điểm bán.',
      confirmLabel: 'Gửi',
    );

    if (!context.mounted || !confirmed) {
      return;
    }

    final service = ref.read(syncServiceProvider.notifier);
    final sent = await service.sendDraft(entry.clientRequestId);

    if (!context.mounted) {
      return;
    }

    final state = ref.read(syncServiceProvider);

    showAppSnack(
      context,
      sent
          ? state.lastSummary ?? 'Đã gửi draft.'
          : state.lastError ?? 'Chưa gửi được. Draft vẫn được giữ.',
      error: !sent,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(orderRepositoryProvider);

    final confirmed = await confirmDialog(
      context,
      title: 'Xóa draft?',
      message: 'Xóa ${entry.localCode} khỏi máy. '
          'Chỉ draft chưa từng gửi mới được xóa.',
      confirmLabel: 'Xóa',
    );

    if (!context.mounted || !confirmed) {
      return;
    }

    try {
      await repository.removeFromQueue(entry.clientRequestId);

      if (!context.mounted) {
        return;
      }

      ref.read(dataVersionProvider.notifier).state++;
      showAppSnack(context, 'Đã xóa draft.');
      onDeleted?.call();
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          ApiException.describe(error),
          error: true,
        );
      }
    }
  }
}
