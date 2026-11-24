import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';

class QuotePaymentSheet extends ConsumerStatefulWidget {
  const QuotePaymentSheet(
      {super.key, required this.order, required this.quote});
  final Order order;
  final SalesOrderQuote quote;

  @override
  ConsumerState<QuotePaymentSheet> createState() => _QuotePaymentSheetState();
}

class _QuotePaymentSheetState extends ConsumerState<QuotePaymentSheet> {
  PaymentMethod _method = PaymentMethod.prepaid;

  @override
  Widget build(BuildContext context) {
    final credit = ref.watch(retailerCreditProvider(widget.order.retailerId));
    final retailer =
        credit.isLoading || credit.hasError ? null : credit.valueOrNull;
    final creditAllowed = retailer != null && retailerCreditAllowed(retailer);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Chấp nhận báo giá và chọn thanh toán',
                style: AppText.pageTitle),
            const SizedBox(height: AppSpacing.s10),
            // Quote summary (prototype: total + response deadline).
            AppCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${widget.order.code} · Báo giá #${widget.quote.revisionNumber}',
                      style: AppText.mutedSmall),
                  Text(Money.format(widget.quote.totalAmount),
                      style: AppText.display
                          .copyWith(fontSize: 24, color: AppColors.primary)),
                  Text(
                      'Hạn phản hồi ${AppDates.timeDay(widget.quote.expiresAt.toLocal())}',
                      style: AppText.muted),
                ],
              ),
            ),
            const SectionTitle('Chọn hình thức thanh toán'),
            _PaymentOption(
              selected: _method == PaymentMethod.prepaid,
              child: ListTile(
                selected: _method == PaymentMethod.prepaid,
                leading: const Icon(Icons.qr_code),
                title: const Text('Trả trước'),
                subtitle: const Text(
                    'Thanh toán đủ để hệ thống phát hành đơn thực hiện.'),
                trailing: Icon(_method == PaymentMethod.prepaid
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                onTap: () => setState(() => _method = PaymentMethod.prepaid),
              ),
            ),
            _PaymentOption(
              selected: _method == PaymentMethod.credit,
              child: ListTile(
                enabled: creditAllowed,
                selected: _method == PaymentMethod.credit,
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Công nợ'),
                subtitle: Text(credit.isLoading
                    ? 'Đang kiểm tra kỳ hạn được duyệt...'
                    : creditAllowed
                        ? 'Kỳ hạn được duyệt: ${retailer.creditTerm} ngày · Hạn mức: ${Money.format(retailer.creditLimit)}'
                        : credit.hasError
                            ? 'Chưa kiểm tra được công nợ. Bạn vẫn có thể chọn trả trước.'
                            : 'Cửa hàng chưa đủ điều kiện công nợ.'),
                trailing: Icon(_method == PaymentMethod.credit
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                onTap: creditAllowed
                    ? () => setState(() => _method = PaymentMethod.credit)
                    : null,
              ),
            ),
            if (credit.hasError)
              TextButton(
                  onPressed: () => ref.invalidate(
                      retailerCreditProvider(widget.order.retailerId)),
                  child: const Text('Kiểm tra lại công nợ')),
            const InfoBanner(
              text:
                  'Hiện chỉ hỗ trợ Trả trước hoặc Công nợ, không thu tiền mặt khi giao hàng. Bạn đang chấp nhận báo giá với phương thức thanh toán đã chọn.',
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: _method == PaymentMethod.credit && !creditAllowed
                  ? null
                  : () => Navigator.of(context).pop(_method),
              child: Text(_method == PaymentMethod.credit
                  ? 'Chấp nhận và chọn công nợ'
                  : 'Chấp nhận và chọn trả trước'),
            ),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Quay lại')),
          ],
        ),
      ),
    );
  }
}

/// Option card around a payment-method tile (prototype radio cards).
class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s10),
        // Material (not a coloured DecoratedBox) so the tile's ink is visible.
        child: Material(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlAll,
            side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
}
