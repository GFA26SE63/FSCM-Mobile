import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Chip for an order: sync state while the order is only on the device,
/// otherwise the order status.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final sync = order.syncStatus;
    if (sync == SyncStatus.pending || sync == SyncStatus.syncing) {
      return StatusChip(label: sync!.label, tone: sync.tone);
    }
    return StatusChip(label: order.status.label, tone: order.status.tone);
  }
}

/// Lines of an order with product names, prices, discounts and (optional)
/// the batches/labels allocated by the FEFO engine.
class OrderLinesCard extends StatelessWidget {
  const OrderLinesCard(this.order, {super.key, this.showBatches = false});

  final Order order;
  final bool showBatches;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < order.lines.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 20),
            _line(order.lines[i]),
          ],
        ],
      ),
    );
  }

  Widget _line(OrderLine l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${l.sku} · ${l.name}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          '${l.qty} thùng × ${Money.format(l.unitPrice)} = ${Money.format(l.base)}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        if (l.discount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: <Widget>[
                StatusChip(
                  label: '${l.promoId} · giảm ${_pct(l.discountPct)}%',
                  tone: StatusTone.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  Money.minus(l.discount),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        if (showBatches)
          for (final b in l.batches)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• ${b.batchCode} · ${b.qty} thùng · HSD ${AppDates.date(b.expiry)}'
                '${b.warehouseName.isEmpty ? '' : ' · ${b.warehouseName}'}'
                '${b.labelCode.isEmpty ? '' : ' · tem ${b.labelCode}'}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted, height: 1.3),
              ),
            ),
      ],
    );
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// "Khuyến mãi áp dụng" summary: one row per promotion.
class AppliedPromoCard extends StatelessWidget {
  const AppliedPromoCard(this.promos,
      {super.key, this.emptyText = 'Không có khuyến mãi.'});

  final List<AppliedPromo> promos;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: promos.isEmpty
          ? Text(emptyText, style: const TextStyle(color: AppColors.textMuted))
          : Column(
              children: <Widget>[
                for (final p in promos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${p.id} · ${p.name}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              if (p.typeLabel.isNotEmpty)
                                Text(
                                  p.typeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              Text(
                                p.detail,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Money.minus(p.amount),
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Tổng tiền hàng / Tổng giảm / Thành tiền.
class TotalsCard extends StatelessWidget {
  const TotalsCard({
    super.key,
    required this.total,
    required this.discount,
    this.finalLabel = 'Thành tiền',
  });

  final int total;
  final int discount;
  final String finalLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          KvRow('Tổng tiền hàng', Money.format(total)),
          KvRow('Tổng giảm', Money.minus(discount),
              valueColor: AppColors.success),
          const Divider(height: 16),
          KvRow(finalLabel, Money.format(total - discount), bold: true),
        ],
      ),
    );
  }
}

/// Vehicle plate + driver snapshot of a dispatched order.
class DeliveryInfoCard extends StatelessWidget {
  const DeliveryInfoCard(this.order, {super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFF1EAFE),
      child: Row(
        children: <Widget>[
          const Icon(Icons.local_shipping_outlined, color: Color(0xFF6D28D9)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Đang giao',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Xe ${order.vehiclePlate} · ${order.driverName}'),
                if (order.driverPhone.isNotEmpty)
                  Text('SĐT ${order.driverPhone}'),
                if (order.departedAt != null)
                  Text(
                    'Xuất phát ${AppDates.time(order.departedAt)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
