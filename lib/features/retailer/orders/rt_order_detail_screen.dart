import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';

/// Retailer order detail: delivery vehicle + driver, lines with batches,
/// promotions, timeline, and the receipt-confirmation entry point.
class RtOrderDetailScreen extends ConsumerWidget {
  const RtOrderDetailScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text(code)),
      body: AsyncBody<Order>(
        value: value,
        onRetry: () => ref.invalidate(orderDetailProvider(code)),
        builder: (o) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                    child: Text(o.code,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
                OrderStatusChip(o),
              ],
            ),
            const SizedBox(height: 4),
            Text('Đặt lúc ${AppDates.timeDay(o.createdAt)}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (o.status == OrderStatus.rejected)
              InfoBanner(
                tone: StatusTone.danger,
                icon: Icons.block,
                title: 'Đơn bị từ chối',
                text: o.rejectReason.isEmpty
                    ? 'Hệ thống từ chối đơn hàng.'
                    : o.rejectReason,
              ),
            if (o.hasDelivery) DeliveryInfoCard(o),
            if (o.status.canConfirmReceipt)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.rtReceive(o.code)),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Quét QR nhận hàng'),
                ),
              ),
            if (o.status == OrderStatus.delivered ||
                o.status == OrderStatus.completed)
              _receiptBanner(o),
            const SectionTitle('Sản phẩm'),
            OrderLinesCard(o, showBatches: o.status != OrderStatus.rejected),
            const SectionTitle('Khuyến mãi áp dụng'),
            AppliedPromoCard(o.appliedPromos,
                emptyText: 'Không có khuyến mãi.'),
            const SizedBox(height: 10),
            TotalsCard(total: o.total, discount: o.discount),
            const SectionTitle('Thanh toán'),
            AppCard(
              child: Column(
                children: <Widget>[
                  KvRow('Hình thức', o.payment.labelWithTerm(o.creditTerm)),
                  if (o.payment == PaymentMethod.credit && o.dueDate != null)
                    KvRow('Hạn thanh toán', AppDates.date(o.dueDate)),
                  KvRow(
                    'Trạng thái',
                    o.paid
                        ? 'Đã thanh toán ${AppDates.timeDay(o.paidAt)}'
                        : 'Chưa thanh toán',
                  ),
                ],
              ),
            ),
            if (o.timeline.isNotEmpty) ...<Widget>[
              const SectionTitle('Tiến trình'),
              AppCard(child: TimelineList(o.timeline)),
            ],
            if (o.status == OrderStatus.delivered ||
                o.status == OrderStatus.completed)
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.rtComplaintFor(o.code)),
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Khiếu nại đơn hàng'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _receiptBanner(Order o) {
    if (o.pointsEarned <= 0) return const SizedBox.shrink();
    return InfoBanner(
      tone: StatusTone.success,
      icon: Icons.stars_outlined,
      title: o.pointsPending
          ? '+${o.pointsEarned} điểm đang chờ cộng'
          : '+${o.pointsEarned} điểm đã cộng',
      text: o.pointsPending
          ? 'Đơn công nợ: điểm được cộng khi bạn thanh toán đủ.'
          : 'Điểm tích lũy từ đơn hàng này đã vào tài khoản.',
    );
  }
}
