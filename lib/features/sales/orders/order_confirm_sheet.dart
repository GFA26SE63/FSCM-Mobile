import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/price_difference_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

class OrderConfirmSheet extends StatelessWidget {
  const OrderConfirmSheet({
    super.key,
    required this.retailer,
    required this.quote,
    required this.online,
    required this.estimated,
    this.localEstimate,
    this.snapshotAt,
    this.estimatedAt,
  });

  final Retailer retailer;
  final PriceQuote quote;
  final bool online;
  final bool estimated;
  final PriceQuote? localEstimate;
  final DateTime? snapshotAt;
  final DateTime? estimatedAt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              'Xác nhận đơn hàng',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text('${retailer.name} · ${retailer.code}'),
            const SizedBox(height: 12),
            InfoBanner(
              text: estimated
                  ? 'Tạm tính trên máy từ snapshot đã lưu. '
                      'Backend sẽ tính lại khi nhận đơn.'
                  : 'Giá dự kiến được máy chủ tính lại cho giỏ hàng này. '
                      'Chưa phải báo giá cuối sau phân bổ.',
            ),
            if (snapshotAt != null) Text('Snapshot: ${_stamp(snapshotAt!)}'),
            if (estimatedAt != null)
              Text('Tính trên máy lúc: ${_stamp(estimatedAt!)}'),
            const SizedBox(height: 10),
            if (!estimated && localEstimate?.isComplete == true)
              PriceDifferenceCard(
                localAmount: localEstimate!.finalAmount,
                serverAmount: quote.finalAmount,
              ),
            if (!quote.isComplete)
              InfoBanner(
                text: 'Thiếu giá: ${quote.missingPriceSkus.join(', ')}. '
                    'Chưa thể xác nhận bản tạm tính.',
              ),
            const SectionTitle('Sản phẩm'),
            for (final line in quote.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${line.name} × ${line.qty}'),
                          if (line.hasDiscount)
                            Text(
                              '${line.promoName} · −${line.pct}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    Text(Money.format(line.net)),
                  ],
                ),
              ),
            const SectionTitle('Khuyến mãi áp dụng'),
            if (quote.applied.isEmpty)
              const Text('Chưa có khuyến mãi áp dụng.')
            else
              for (final promo in quote.applied)
                KvRow(promo.name, Money.minus(promo.amount)),
            const SectionTitle('Thanh toán'),
            const InfoBanner(
              text: 'Retailer chọn phương thức thanh toán sau khi '
                  'hệ thống phân bổ và gửi báo giá chính thức.',
            ),
            if (quote.isComplete) ...[
              const Divider(height: 24),
              KvRow('Tiền hàng dự kiến', Money.format(quote.total)),
              KvRow('Giảm dự kiến', Money.minus(quote.discount)),
              KvRow(
                'Thành tiền dự kiến',
                Money.format(quote.finalAmount),
                bold: true,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: quote.isComplete
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(
                online ? 'Xác nhận tạo SO' : 'Lưu SO trên máy',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Quay lại giỏ hàng'),
            ),
          ],
        ),
      ),
    );
  }

  String _stamp(DateTime value) {
    final local = value.toLocal();
    String pad(int number) => number.toString().padLeft(2, '0');

    return '${pad(local.hour)}:${pad(local.minute)} '
        '${pad(local.day)}/${pad(local.month)}/${local.year}';
  }
}
