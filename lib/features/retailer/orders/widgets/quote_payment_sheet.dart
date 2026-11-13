import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';

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
            16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chấp nhận báo giá và chọn thanh toán',
                style: Theme.of(context).textTheme.titleLarge),
            Text(
                '${widget.order.code} · Báo giá #${widget.quote.revisionNumber}'),
            Text(Money.format(widget.quote.totalAmount),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(
                'Hạn phản hồi ${AppDates.timeDay(widget.quote.expiresAt.toLocal())}'),
            const SizedBox(height: 12),
            ListTile(
              selected: _method == PaymentMethod.prepaid,
              leading: const Icon(Icons.qr_code),
              title: const Text('Trả trước'),
              subtitle: const Text('Thanh toán đủ để hệ thống phát hành PO.'),
              trailing: Icon(_method == PaymentMethod.prepaid
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              onTap: () => setState(() => _method = PaymentMethod.prepaid),
            ),
            ListTile(
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
            if (credit.hasError)
              TextButton(
                  onPressed: () => ref.invalidate(
                      retailerCreditProvider(widget.order.retailerId)),
                  child: const Text('Kiểm tra lại công nợ')),
            const Text(
                'Không áp dụng COD. Bạn đang chấp nhận báo giá với phương thức thanh toán đã chọn.'),
            const SizedBox(height: 12),
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
