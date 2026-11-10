import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_orders_controller.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_delivery_progress.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_prepaid_payment.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_quote_panel.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';

class RtOrderDetailScreen extends ConsumerWidget {
  const RtOrderDetailScreen({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderDetailProvider(code));
    Future<void> refresh() async {
      final orderId = value.valueOrNull?.id;
      if (orderId != null && orderId.isNotEmpty) {
        ref.invalidate(orderQuotesProvider(orderId));
        ref.invalidate(deliveryShipmentsProvider(orderId));
      }
      final retailerId = value.valueOrNull?.retailerId;
      if (retailerId != null && retailerId.isNotEmpty) {
        ref.invalidate(retailerCreditProvider(retailerId));
      }
      ref.invalidate(ordersProvider);
      ref.invalidate(retailerOrdersProvider);
      ref.invalidate(orderDetailProvider(code));
      await ref.read(orderDetailProvider(code).future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(value.valueOrNull?.code ?? 'Chi tiết đơn hàng'),
        actions: [
          IconButton(
            tooltip: 'Tải lại đơn hàng',
            onPressed: () {
              refresh().catchError((Object _) {});
            },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: AsyncBody<Order>(
        value: value,
        onRetry: () => ref.invalidate(orderDetailProvider(code)),
        builder: (order) => RefreshIndicator(
          onRefresh: () async {
            try {
              await refresh();
            } catch (_) {/* Rendered by AsyncBody. */}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                    child: Text(order.code,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
                OrderStatusChip(order),
              ]),
              const SizedBox(height: 4),
              Text('${order.retailerName} · ${order.retailerCode}',
                  style: const TextStyle(color: AppColors.textMuted)),
              Text('Đặt lúc ${AppDates.timeDay(order.createdAt.toLocal())}',
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              if (order.status.isRejectedOrCancelled)
                InfoBanner(
                    tone: StatusTone.danger,
                    icon: Icons.block,
                    title: order.status.label,
                    text: order.rejectReason.isEmpty
                        ? 'Đơn đã kết thúc với trạng thái trên.'
                        : order.rejectReason),
              if (order.status == OrderStatus.quoted)
                RetailerQuotePanel(key: ValueKey(order.id), order: order),
              if (order.canPayOnline)
                RetailerPrepaidPayment(key: ValueKey(order.id), order: order),
              if (order.hasDelivery) DeliveryInfoCard(order),
              if (order.pointsEarned > 0 &&
                  (order.status == OrderStatus.delivered ||
                      order.status == OrderStatus.completed))
                InfoBanner(
                    tone: StatusTone.success,
                    icon: Icons.stars_outlined,
                    title:
                        '+${order.pointsEarned} điểm ${order.pointsPending ? 'đang chờ cộng' : 'đã cộng'}',
                    text: order.pointsPending
                        ? 'Điểm được cộng khi thanh toán đủ.'
                        : 'Điểm đã vào tài khoản của bạn.'),
              const SectionTitle('Sản phẩm'),
              OrderLinesCard(order,
                  showBatches: !order.status.isRejectedOrCancelled),
              const SectionTitle('Khuyến mãi áp dụng'),
              AppliedPromoCard(order.appliedPromos,
                  emptyText: 'Không có khuyến mãi.'),
              const SizedBox(height: 10),
              if (order.finalPricePendingAllocation)
                const InfoBanner(
                    text:
                        'Giá đang là dự kiến; giá chính thức được chốt theo kết quả phân bổ.'),
              TotalsCard(total: order.total, discount: order.discount),
              const SectionTitle('Thanh toán'),
              AppCard(
                  child: Column(children: [
                KvRow(
                    'Hình thức', order.payment.labelWithTerm(order.creditTerm)),
                if (order.payment == PaymentMethod.credit &&
                    order.dueDate != null)
                  KvRow('Hạn thanh toán', AppDates.date(order.dueDate)),
                KvRow(
                    'Trạng thái',
                    order.payment == PaymentMethod.unselected
                        ? 'Chọn khi chấp nhận báo giá'
                        : order.paid
                            ? 'Đã thanh toán${order.paidAt == null ? '' : ' ${AppDates.timeDay(order.paidAt!.toLocal())}'}'
                            : 'Chưa thanh toán'),
              ])),
              const SectionTitle('Tiến độ phân bổ / giao hàng'),
              if (order.allocationState.isNotEmpty ||
                  order.allocationResult != null)
                AppCard(
                    child: Column(children: [
                  if (order.allocationState.isNotEmpty)
                    KvRow('Phân bổ', order.allocationState),
                  if (order.allocationResult != null)
                    KvRow('Kết quả', order.allocationResult!),
                ])),
              RetailerDeliveryProgress(order: order),
              const SectionTitle('Tiến trình'),
              if (order.timeline.isEmpty)
                const InfoBanner(
                    text: 'Chưa có sự kiện tiến trình được trả về.')
              else
                AppCard(child: TimelineList(order.timeline)),
              if (order.status == OrderStatus.delivered ||
                  order.status == OrderStatus.completed)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.rtComplaintFor(order.id)),
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                  label: const Text('Khiếu nại đơn hàng'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
