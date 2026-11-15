import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

class RetailerDeliveryProgress extends ConsumerWidget {
  const RetailerDeliveryProgress({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (![
      OrderStatus.convertedToPo,
      OrderStatus.picking,
      OrderStatus.issued,
      OrderStatus.delivering,
      OrderStatus.delivered,
      OrderStatus.completed
    ].contains(order.status)) {
      return InfoBanner(
          text: order.status == OrderStatus.allocating
              ? 'Hệ thống đang phân bổ. Báo giá chính thức sẽ có sau khi chọn hàng.'
              : order.status == OrderStatus.paymentPending
                  ? 'Đơn đang chờ thanh toán trước khi phát hành PO và tạo phần giao.'
                  : 'Chưa có phần giao hàng cho trạng thái hiện tại.');
    }
    final value = ref.watch(deliveryShipmentsProvider(order.id));
    return value.when(
      data: (shipments) => shipments.isEmpty
          ? const InfoBanner(
              text: 'Chưa có phần giao hàng được tạo. Tải lại để cập nhật.')
          : Column(children: [
              for (final shipment in shipments)
                AppCard(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(shipment.code,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    KvRow(
                        'Kho',
                        shipment.warehouseName.isEmpty
                            ? shipment.warehouseCode
                            : shipment.warehouseName),
                    KvRow('Trạng thái', shipment.statusLabel),
                    KvRow('Đã nhận / tổng',
                        '${shipment.receivedQuantity} / ${shipment.totalQuantity} thùng'),
                    if (shipment.plateNumber.isNotEmpty)
                      KvRow('Biển số xe', shipment.plateNumber),
                    if (shipment.driverName.isNotEmpty)
                      KvRow('Tài xế', shipment.driverName),
                    if (shipment.driverPhone.isNotEmpty)
                      KvRow('Liên hệ', shipment.driverPhone),
                    if (shipment.dispatchedAt != null)
                      KvRow('Bắt đầu giao',
                          AppDates.timeDay(shipment.dispatchedAt!.toLocal())),
                    if (shipment.receivedAt != null)
                      KvRow('Đã nhận lúc',
                          AppDates.timeDay(shipment.receivedAt!.toLocal())),
                    if (shipment.exceptionReason.isNotEmpty)
                      InfoBanner(
                          tone: StatusTone.warning,
                          text: shipment.exceptionReason),
                    if (shipment.canReceive)
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.rtReceive(order.id)),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Chọn phần giao và quét nhận hàng'),
                      ),
                  ],
                )),
            ]),
      loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InfoBanner(
            tone: StatusTone.warning, text: ApiException.describe(error)),
        TextButton(
            onPressed: () =>
                ref.invalidate(deliveryShipmentsProvider(order.id)),
            child: const Text('Tải lại tiến độ giao hàng')),
      ]),
    );
  }
}
