import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';
import 'package:fscm_mobile/sync/sync_service.dart';

/// Order detail for Sales: product names, promotions, offline/sync info,
/// promotion comparison when the server re-priced the order.
class SalesOrderDetailScreen extends ConsumerWidget {
  const SalesOrderDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(code));
    final queue =
        ref.watch(offlineQueueProvider).valueOrNull ?? const <OfflineOrder>[];
    return Scaffold(
      appBar: AppBar(title: Text(code)),
      body: AsyncBody<Order>(
        value: value,
        onRetry: () => ref.invalidate(orderDetailProvider(code)),
        builder: (o) {
          final entry = queue
              .where((e) =>
                  e.localCode == o.offlineCode && o.offlineCode.isNotEmpty)
              .toList();
          return _Detail(order: o, entry: entry.isEmpty ? null : entry.first);
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.order, required this.entry});

  final Order order;
  final OfflineOrder? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = order;
    final online = ref.watch(networkMonitorProvider).online;
    final queued = entry != null && entry!.status == SyncStatus.pending;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(o.displayCode,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            OrderStatusChip(o),
          ],
        ),
        const SizedBox(height: 4),
        Text('${o.retailerName} · ${o.retailerCode}',
            style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 10),
        if (o.status == OrderStatus.rejected)
          InfoBanner(
            tone: StatusTone.danger,
            icon: Icons.block,
            title: 'Lý do từ chối',
            text: o.rejectReason.isEmpty
                ? 'Hệ thống từ chối đơn hàng.'
                : o.rejectReason,
          ),
        if (o.syncStatus == SyncStatus.pending ||
            o.syncStatus == SyncStatus.syncing)
          const InfoBanner(
            icon: Icons.save_alt,
            text:
                'Đơn đang lưu trên máy. Khi có mạng, đơn được gửi lên hệ thống; hệ thống sẽ tính lại khuyến mãi và phân bổ kho, batch. Kết quả của hệ thống là chính thức.',
          ),
        if (o.promoChanged) _PromoComparison(order: o),
        if (o.hasDelivery) DeliveryInfoCard(o),
        const SectionTitle('Sản phẩm'),
        OrderLinesCard(o, showBatches: o.status != OrderStatus.rejected),
        const SectionTitle('Khuyến mãi áp dụng'),
        AppliedPromoCard(o.appliedPromos, emptyText: 'Không có khuyến mãi.'),
        const SizedBox(height: 10),
        TotalsCard(total: o.total, discount: o.discount),
        const SectionTitle('Thông tin đơn'),
        AppCard(
          child: Column(
            children: <Widget>[
              KvRow('Thanh toán', o.payment.labelWithTerm(o.creditTerm)),
              KvRow(
                  'Người tạo', o.createdByName.isEmpty ? '—' : o.createdByName),
              KvRow('Kênh tạo', o.isOffline ? 'Offline (OFF)' : 'Online'),
              KvRow('Đặt hàng lúc', AppDates.timeDay(o.createdAt)),
              if (o.isOffline && o.offlineCode.isNotEmpty)
                KvRow('Mã tạm trên máy', o.offlineCode),
              if (o.syncedAt != null)
                KvRow('Tới hệ thống lúc', AppDates.timeDay(o.syncedAt)),
              if (o.syncMode.isNotEmpty) KvRow('Cách đồng bộ', o.syncMode),
            ],
          ),
        ),
        if (o.timeline.isNotEmpty) ...<Widget>[
          const SectionTitle('Tiến trình'),
          AppCard(child: TimelineList(o.timeline)),
        ],
        const SizedBox(height: 8),
        if (queued && online)
          FilledButton.icon(
            onPressed: () =>
                ref.read(syncServiceProvider.notifier).syncAll(manual: true),
            icon: const Icon(Icons.sync),
            label: const Text('Đồng bộ ngay'),
          ),
        if (queued) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _removeFromQueue(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa khỏi hàng đợi đồng bộ'),
          ),
        ],
        if (o.syncStatus == null && o.status == OrderStatus.pending)
          OutlinedButton.icon(
            onPressed: () => _cancel(context, ref),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Hủy đơn (đang chờ duyệt)'),
          ),
      ],
    );
  }

  Future<void> _removeFromQueue(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa đơn khỏi máy?',
      message:
          'Đơn ${order.offlineCode} chưa gửi lên hệ thống sẽ bị xóa và không thể khôi phục.',
      confirmLabel: 'Xóa',
    );
    if (!ok) return;
    await ref
        .read(orderRepositoryProvider)
        .removeFromQueue(entry!.clientRequestId);
    ref.read(dataVersionProvider.notifier).state++;
    if (context.mounted) context.pop();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Hủy đơn ${order.code}?',
      message: 'Hàng đang giữ cho đơn sẽ được giải phóng.',
      confirmLabel: 'Hủy đơn',
      cancelLabel: 'Không',
    );
    if (!ok) return;
    try {
      await ref.read(orderRepositoryProvider).cancel(order.code);
      ref.read(dataVersionProvider.notifier).state++;
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

/// "Khuyến mãi thay đổi khi đồng bộ": local estimate vs official result.
class _PromoComparison extends StatelessWidget {
  const _PromoComparison({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final local = order.localFinal ?? order.finalAmount;
    final official = order.finalAmount;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tone(StatusTone.warning).background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Khuyến mãi thay đổi khi đồng bộ',
              style: TextStyle(fontWeight: FontWeight.w800)),
          if (order.changeReason.isNotEmpty) Text(order.changeReason),
          const SizedBox(height: 6),
          KvRow('Tạm tính trên máy', Money.format(local)),
          KvRow('Chính thức (hệ thống)', Money.format(official), bold: true),
          KvRow('Chênh lệch thành tiền', Money.format(official - local),
              valueColor: AppColors.danger),
        ],
      ),
    );
  }
}
