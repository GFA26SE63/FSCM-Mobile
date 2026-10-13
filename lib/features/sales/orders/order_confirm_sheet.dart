import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Bottom sheet "Xác nhận đơn hàng": lines, applied promotions, totals and
/// payment choice. Pops with the chosen [PaymentMethod].
class OrderConfirmSheet extends StatefulWidget {
  const OrderConfirmSheet({
    super.key,
    required this.retailer,
    required this.quote,
    required this.online,
    required this.estimated,
  });

  final Retailer retailer;
  final PriceQuote quote;
  final bool online;

  /// True when [quote] is the local estimate (offline or quote API failed).
  final bool estimated;

  @override
  State<OrderConfirmSheet> createState() => _OrderConfirmSheetState();
}

class _OrderConfirmSheetState extends State<OrderConfirmSheet> {
  PaymentMethod _payment = PaymentMethod.cod;

  bool _enabled(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cod:
        return true;
      case PaymentMethod.prepaid:
        return widget.online;
      case PaymentMethod.credit:
        return widget.retailer.creditAllowed;
    }
  }

  String _hint(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cod:
        return 'Retailer trả tiền khi nhận hàng';
      case PaymentMethod.prepaid:
        return widget.online
            ? 'Chuyển khoản QR hoặc tiền mặt trước khi giao'
            : 'Cần có mạng để trả trước';
      case PaymentMethod.credit:
        return widget.retailer.creditAllowed
            ? 'Trả một lần đủ trong ${widget.retailer.creditTerm} ngày kể từ ngày giao'
            : 'Điểm bán chưa được phép mua công nợ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            const Text('Xác nhận đơn hàng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Giao đến ${widget.retailer.name} · ${widget.retailer.code}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (widget.estimated)
              InfoBanner(
                tone: StatusTone.warning,
                text: widget.online
                    ? 'Không lấy được giá từ hệ thống - đang hiển thị khuyến mãi tạm tính trên máy.'
                    : 'Khuyến mãi tạm tính trên máy (offline). Hệ thống sẽ tính lại khi đồng bộ.',
              ),
            const SectionTitle('Sản phẩm'),
            for (final l in q.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${l.name} ×${l.qty}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (l.hasDiscount)
                            Text('${l.promoId} · −${l.pct.round()}%',
                                style: const TextStyle(
                                    color: AppColors.success, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(Money.format(l.base - l.discount)),
                  ],
                ),
              ),
            const SectionTitle('Khuyến mãi áp dụng'),
            if (q.applied.isEmpty)
              const Text('Đơn chưa đạt điều kiện khuyến mãi nào.',
                  style: TextStyle(color: AppColors.textMuted))
            else
              for (final a in q.applied)
                KvRow('${a.id} · ${a.name}', Money.minus(a.amount),
                    valueColor: AppColors.success),
            const SectionTitle('Thanh toán'),
            for (final m in PaymentMethod.values)
              RadioListTile<PaymentMethod>(
                contentPadding: EdgeInsets.zero,
                value: m,
                groupValue: _payment,
                onChanged: _enabled(m)
                    ? (v) => setState(() => _payment = v ?? _payment)
                    : null,
                title: Text(m.labelWithTerm(widget.retailer.creditTerm)),
                subtitle: Text(_hint(m)),
              ),
            const Divider(height: 24),
            KvRow('Tổng tiền hàng', Money.format(q.total)),
            KvRow('Tổng giảm', Money.minus(q.discount),
                valueColor: AppColors.success),
            KvRow('Thành tiền', Money.format(q.finalAmount), bold: true),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_payment),
              child: Text(
                  widget.online ? 'Xác nhận đặt hàng' : 'Lưu đơn trên máy'),
            ),
            const SizedBox(height: 6),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại giỏ hàng')),
          ],
        ),
      ),
    );
  }
}
