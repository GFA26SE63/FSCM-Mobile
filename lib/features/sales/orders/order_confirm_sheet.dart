import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';

/// Bottom sheet "Xác nhận đơn hàng" matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.sales` CONFIRM). Pops with a [PaymentMethod].
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
    final loyaltyPoints = (q.finalAmount / 100000).floor();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: <Widget>[
            const Text(
              'Xác nhận đơn hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Bước 3 / 3 · Kiểm tra & gửi đơn',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (estimated)
              InfoBanner(
                tone: StatusTone.warning,
                text: online
                    ? 'Không lấy được giá từ hệ thống - đang hiển thị khuyến mãi tạm tính trên máy.'
                    : 'Đang ngoại tuyến: khuyến mãi đang tính tạm theo bảng giá lưu trên máy. Khi gửi lên hệ thống, giá & khuyến mãi sẽ được tính lại.',
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Điểm bán',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    retailer.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Mã ${retailer.code} · ${retailer.address}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Danh sách mặt hàng (${q.lines.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (int i = 0; i < q.lines.length; i++) ...<Widget>[
                    if (i > 0)
                      const Divider(height: 14, color: Color(0xFFEEF0EC)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                q.lines[i].name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${q.lines[i].sku} · × ${q.lines[i].qty}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (q.lines[i].hasDiscount)
                                Text(
                                  '${q.lines[i].promoId} (−${q.lines[i].pct.round()}%): ${Money.minus(q.lines[i].discount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            if (q.lines[i].hasDiscount)
                              Text(
                                Money.format(q.lines[i].base),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              Money.format(
                                  q.lines[i].base - q.lines[i].discount),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Khuyến mãi áp dụng (dự kiến)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (q.applied.isEmpty)
                    const Text(
                      'Không có khuyến mãi áp dụng.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    for (final a in q.applied)
                      KvRow(
                        '${a.id} · ${a.name}',
                        Money.minus(a.amount),
                        valueColor: AppColors.success,
                      ),
                ],
              ),
            ),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Thanh toán',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Retailer chọn Trả trước hoặc Công nợ sau khi nhận báo giá từ nhà phân phối.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KvRow('Giá niêm yết', Money.format(q.total)),
                  KvRow(
                    'KM thường',
                    Money.minus(q.discount),
                    valueColor: AppColors.success,
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Thành tiền (dự kiến)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        Money.format(q.finalAmount),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Điểm loyalty dự kiến: +$loyaltyPoints điểm (tính trên Thành tiền sau khi xuất kho)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(PaymentMethod.prepaid),
              icon: Icon(online ? Icons.send : Icons.save_outlined, size: 18),
              label: Text(
                online ? 'Gửi đơn lên hệ thống' : 'Lưu đơn nháp trên máy',
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Quay lại giỏ hàng'),
            ),
          ],
        ),
      ),
    );
  }
}
