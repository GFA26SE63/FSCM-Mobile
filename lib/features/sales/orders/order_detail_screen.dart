import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/price_difference_card.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/allocation_retry_button.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/offline_draft_actions.dart';

class SalesOrderDetailScreen extends ConsumerWidget {
  const SalesOrderDetailScreen({
    super.key,
    required this.code,
  });

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(code));
    final queue = ref.watch(offlineQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(code),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () {
              ref.invalidate(orderDetailProvider(code));
              ref.invalidate(offlineQueueProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncBody<Order>(
        value: value,
        onRetry: () {
          ref.invalidate(orderDetailProvider(code));
          ref.invalidate(offlineQueueProvider);
        },
        builder: (order) {
          final entries = queue.valueOrNull ?? const <OfflineOrder>[];

          final matches = entries.where(
            (entry) =>
                (order.offlineCode.isNotEmpty &&
                    entry.localCode == order.offlineCode) ||
                (order.code.isNotEmpty &&
                    entry.serverOrderCode == order.code) ||
                entry.localCode == code,
          );

          return _Detail(
            order: order,
            entry: matches.isEmpty ? null : matches.first,
          );
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.order,
    required this.entry,
  });

  final Order order;
  final OfflineOrder? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localQueued = order.isLocalQueued;
    final hasStoredQuote = entry?.payload.localQuote != null;

    final localAmount = order.localFinal ??
        (entry?.status == SyncStatus.synced ? entry?.payload.localFinal : null);

    final estimatedAt = entry?.payload.estimatedAt;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.displayCode,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OrderStatusChip(order),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${order.retailerName} · ${order.retailerCode}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        AllocationRetryButton(order: order),
        if (order.syncStatus == SyncStatus.synced && entry?.serverOrder != null)
          const InfoBanner(
            text: 'Đang xem kết quả đã lưu lúc gửi. '
                'Tải lại khi có mạng để cập nhật tiến trình đơn.',
          ),
        if (order.status.isRejectedOrCancelled)
          InfoBanner(
            tone: StatusTone.danger,
            icon: Icons.block,
            title: 'Lý do từ chối',
            text: order.rejectReason.isEmpty
                ? 'Hệ thống từ chối đơn hàng.'
                : order.rejectReason,
          ),
        if (order.syncStatus?.isUnsent == true)
          const InfoBanner(
            icon: Icons.save_alt,
            text: 'Đơn đang lưu trên máy. Giá và khuyến mãi là bản '
                'tạm tính lúc lưu, không phải báo giá cuối. '
                'Backend sẽ tính lại khi nhận đơn.',
          ),
        if (localQueued && !hasStoredQuote)
          const InfoBanner(
            tone: StatusTone.warning,
            text: 'Đơn cũ chỉ còn số tiền tạm tính đã lưu, không có '
                'bản giá chi tiết từng dòng. Ứng dụng không dùng '
                'catalog mới để thay thế giá ban đầu.',
          ),
        if (!localQueued && localAmount != null)
          PriceDifferenceCard(
            localAmount: localAmount,
            serverAmount: order.finalAmount,
            title: 'Đối chiếu với bản offline',
            serverLabel: 'Giá hệ thống hiện tại',
          ),
        if (entry?.status == SyncStatus.synced && entry?.finalAmount != null)
          PriceDifferenceCard(
            localAmount: entry!.payload.localFinal,
            serverAmount: entry!.finalAmount!,
            title: 'Đối chiếu tại thời điểm gửi',
            serverLabel: 'Kết quả server lúc gửi',
          ),
        if (!localQueued && order.changeReason.isNotEmpty)
          InfoBanner(text: order.changeReason),
        if (order.hasDelivery) DeliveryInfoCard(order),
        if (!localQueued || hasStoredQuote) ...[
          const SectionTitle('Sản phẩm'),
          OrderLinesCard(
            order,
            showBatches: !order.status.isRejectedOrCancelled,
          ),
          const SectionTitle('Khuyến mãi áp dụng'),
          AppliedPromoCard(
            order.appliedPromos,
            emptyText: 'Không có khuyến mãi.',
          ),
          const SizedBox(height: 10),
          if (localQueued)
            const InfoBanner(
              text: 'Các khoản tiền bên dưới là tạm tính đã lưu trên máy.',
            ),
          TotalsCard(
            total: order.total,
            discount: order.discount,
          ),
        ] else
          AppCard(
            child: KvRow(
              'Số tiền tạm tính đã lưu',
              Money.format(order.localFinal ?? order.finalAmount),
            ),
          ),
        const SectionTitle('Thông tin đơn'),
        AppCard(
          child: Column(
            children: [
              KvRow(
                'Thanh toán',
                order.payment.labelWithTerm(order.creditTerm),
              ),
              if (entry != null) KvRow('Trạng thái gửi', entry!.status.label),
              KvRow(
                'Người tạo',
                order.createdByName.isEmpty ? '—' : order.createdByName,
              ),
              KvRow(
                'Kênh tạo',
                order.isOffline ? 'Offline (OFF)' : 'Online',
              ),
              KvRow(
                'Đặt hàng lúc',
                AppDates.timeDay(order.createdAt.toLocal()),
              ),
              if (estimatedAt != null)
                KvRow(
                  'Tạm tính trên máy lúc',
                  AppDates.timeDay(estimatedAt.toLocal()),
                ),
              if (order.offlineCode.isNotEmpty)
                KvRow('Mã tạm trên máy', order.offlineCode)
              else if (entry != null)
                KvRow('Mã tạm trên máy', entry!.localCode),
              if (entry?.serverOrderCode.isNotEmpty == true)
                KvRow('Mã đơn server', entry!.serverOrderCode)
              else if (order.code.isNotEmpty)
                KvRow('Mã đơn server', order.code),
              if (order.syncedAt != null)
                KvRow(
                  'Đồng bộ lúc',
                  AppDates.timeDay(order.syncedAt!.toLocal()),
                )
              else if (entry?.syncedAt != null)
                KvRow(
                  'Đồng bộ lúc',
                  AppDates.timeDay(entry!.syncedAt!.toLocal()),
                ),
              if (order.syncMode.isNotEmpty)
                KvRow('Cách đồng bộ', order.syncMode)
              else if (entry?.syncMode.isNotEmpty == true)
                KvRow('Cách đồng bộ', entry!.syncMode),
            ],
          ),
        ),
        if (order.timeline.isNotEmpty) ...[
          const SectionTitle('Tiến trình'),
          AppCard(
            child: TimelineList(order.timeline),
          ),
        ],
        const SizedBox(height: 8),
        if (entry != null)
          OfflineDraftActions(
            entry: entry!,
            onDeleted: () => context.pop(),
          ),
        if (order.syncStatus == null && order.status == OrderStatus.allocating)
          OutlinedButton.icon(
            onPressed: () => _cancel(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Hủy đơn'),
          ),
      ],
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(orderRepositoryProvider);

    final confirmed = await confirmDialog(
      context,
      title: 'Hủy đơn ${order.code}?',
      message: 'Bạn muốn gửi yêu cầu hủy đơn hàng này?',
      confirmLabel: 'Hủy đơn',
      cancelLabel: 'Không',
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await repository.cancel(order.id, order.version);

      if (!context.mounted) {
        return;
      }

      ref.read(dataVersionProvider.notifier).state++;
    } on ApiException catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          error.message,
          error: true,
        );
      }
    }
  }
}
