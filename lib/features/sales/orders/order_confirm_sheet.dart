import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:flutter/material.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/features/sales/orders/widgets/price_difference_card.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
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
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          children: [
            const Text(
              'Xác nhận đơn hàng',
              style: AppText.display,
            ),
            Text('${retailer.name} · ${retailer.code}'),
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              text: estimated
                  ? 'Tạm tính trên máy từ dữ liệu đồng bộ đã lưu. '
                      'Máy chủ sẽ tính lại khi nhận đơn.'
                  : 'Giá dự kiến được máy chủ tính lại cho giỏ hàng này. '
                      'Chưa phải báo giá cuối sau phân bổ.',
            ),
            if (snapshotAt != null)
              Text('Dữ liệu đồng bộ lúc: ${_stamp(snapshotAt!)}'),
            if (estimatedAt != null)
              Text('Tính trên máy lúc: ${_stamp(estimatedAt!)}'),
            const SizedBox(height: AppSpacing.s10),
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
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < quote.lines.length; i++)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(
                                top: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${quote.lines[i].name} × ${quote.lines[i].qty}',
                                    style: AppText.cardTitle
                                        .copyWith(fontSize: 14)),
                                if (quote.lines[i].hasDiscount)
                                  Text(
                                    '${quote.lines[i].promoName} · −${quote.lines[i].pct}%',
                                    style: AppText.bodySmall
                                        .copyWith(color: AppColors.warning),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(Money.format(quote.lines[i].net),
                              style: AppText.cardTitle.copyWith(fontSize: 14)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SectionTitle('Khuyến mãi áp dụng'),
            const InfoBanner(
              text:
                  'Hệ thống tự động áp dụng chương trình có mức giảm cao nhất cho từng sản phẩm (không cộng dồn các CTKM thương mại). '
                  'Chiết khấu HSD (nếu phân bổ trúng lô cận date) sẽ được tính thêm trên báo giá chính thức.',
            ),
            if (quote.applied.isEmpty)
              const Text('Chưa có khuyến mãi áp dụng.', style: AppText.muted)
            else
              for (final promo in quote.applied)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.s10),
                  decoration: const BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: AppRadius.smallAll,
                  ),
                  child: DefaultTextStyle.merge(
                    style: AppText.cardTitle
                        .copyWith(fontSize: 14, color: AppColors.warning),
                    child: KvRow(promo.name, Money.minus(promo.amount),
                        valueColor: AppColors.warning),
                  ),
                ),
            const SectionTitle('Thanh toán'),
            const InfoBanner(
              text: 'Điểm bán chọn phương thức thanh toán sau khi '
                  'hệ thống phân bổ và gửi báo giá chính thức.',
            ),
            if (quote.isComplete)
              AppCard(
                child: Column(
                  children: [
                    KvRow('Tiền hàng dự kiến', Money.format(quote.total)),
                    KvRow('Giảm dự kiến', Money.minus(quote.discount)),
                    const Divider(height: AppSpacing.xl),
                    KvRow(
                      'Thành tiền dự kiến',
                      Money.format(quote.finalAmount),
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: quote.isComplete
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(
                online ? 'Gửi đơn hàng' : 'Lưu bản nháp trên máy',
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
    return AppDates.timeDay(value);
  }
}
