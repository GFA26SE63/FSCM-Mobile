import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

/// Bottom sheet "Xác nhận đơn hàng": lines, applied promotions, totals and
/// This step confirms the SO contents only. Payment is deliberately selected
/// by the Retailer after allocation has produced the official quotation.
class OrderConfirmSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final q = quote;
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
            Text('Giao đến ${retailer.name} · ${retailer.code}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (estimated)
              InfoBanner(
                tone: StatusTone.warning,
                text: online
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
            const InfoBanner(
              tone: StatusTone.info,
              text:
                  'Retailer sẽ chọn trả trước hoặc công nợ sau khi hệ thống phân bổ batch, tính giảm HSD và gửi báo giá chính thức. Không áp dụng COD.',
            ),
            const Divider(height: 24),
            KvRow('Tổng tiền hàng', Money.format(q.total)),
            KvRow('Tổng giảm', Money.minus(q.discount),
                valueColor: AppColors.success),
            KvRow('Thành tiền', Money.format(q.finalAmount), bold: true),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                  online ? 'Xác nhận tạo SO' : 'Lưu SO trên máy'),
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
