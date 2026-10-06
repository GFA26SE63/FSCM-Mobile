import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final SalesOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = switch (status) {
      SalesOrderStatus.pendingSync => (
        'Chờ đồng bộ',
        const Color(0xFF374151),
        const Color(0xFFECEEF1),
      ),
      SalesOrderStatus.syncing => (
        'Đang đồng bộ',
        FscmColors.info,
        const Color(0xFFE8EEFD),
      ),
      SalesOrderStatus.pendingApproval => (
        'Chờ duyệt',
        FscmColors.info,
        const Color(0xFFE8EEFD),
      ),
      SalesOrderStatus.approved => (
        'Đã duyệt',
        FscmColors.primary,
        const Color(0xFFE1F1EC),
      ),
      SalesOrderStatus.dispatched => (
        'Đã xuất kho',
        FscmColors.primary,
        const Color(0xFFE1F1EC),
      ),
      SalesOrderStatus.delivering => (
        'Đang giao',
        FscmColors.purple,
        const Color(0xFFF1EAFE),
      ),
      SalesOrderStatus.delivered => (
        'Đã giao',
        const Color(0xFF15703A),
        const Color(0xFFE5F4EA),
      ),
      SalesOrderStatus.rejected => (
        'Bị từ chối',
        FscmColors.danger,
        const Color(0xFFFDECEA),
      ),
      SalesOrderStatus.cancelled => (
        'Đã hủy',
        const Color(0xFF4B5563),
        const Color(0xFFECEEF1),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, required this.order, this.onTap});

  final SalesOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FscmCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.retailer.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            order.lines
                .map((line) => '${line.product.name} ×${line.quantity}')
                .join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: FscmColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                order.wasOffline
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                size: 16,
                color: FscmColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                order.createdAt,
                style: const TextStyle(fontSize: 12, color: FscmColors.muted),
              ),
              const Spacer(),
              Text(
                formatVnd(order.total),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: FscmColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
