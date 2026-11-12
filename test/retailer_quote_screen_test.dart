import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/quote_payment_sheet.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_quote_panel.dart';

import 'fixtures/retailer_order_fixture.dart';

void main() {
  testWidgets(
      'latest expired quote disables both decisions despite an older issued quote',
      (tester) async {
    final order = retailerOrderFixture();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          orderQuotesProvider(order.id).overrideWith((ref) async => [
                retailerQuoteFixture(),
                retailerQuoteFixture(revision: 2, expiresAt: DateTime.utc(2000))
              ]),
        ],
        child: MaterialApp(
            home: Scaffold(body: RetailerQuotePanel(order: order)))));
    await tester.pumpAndSettle();
    expect(find.text('Báo giá chính thức #2'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(
                FilledButton, 'Chấp nhận và chọn thanh toán'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Từ chối báo giá'))
            .onPressed,
        isNull);
  });

  testWidgets(
      'unapproved credit stays disabled while Prepaid remains selectable',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          retailerCreditProvider('retailer-1')
              .overrideWith((ref) async => creditRetailerFixture(0)),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: QuotePaymentSheet(
          order: retailerOrderFixture(),
          quote: retailerQuoteFixture(),
        )))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Công nợ'))
            .enabled,
        isFalse);
    expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Trả trước'))
            .enabled,
        isTrue);
    expect(find.text('Chấp nhận và chọn trả trước'), findsOneWidget);
  });

  testWidgets('approved credit requires explicit selection and returns Credit',
      (tester) async {
    PaymentMethod? result;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          retailerCreditProvider('retailer-1')
              .overrideWith((ref) async => creditRetailerFixture(14)),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                          onPressed: () async {
                            result = await showModalBottomSheet<PaymentMethod>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => QuotePaymentSheet(
                                    order: retailerOrderFixture(),
                                    quote: retailerQuoteFixture()));
                          },
                          child: const Text('Open'),
                        ))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Công nợ'));
    await tester.tap(find.text('Công nợ'));
    await tester.pumpAndSettle();
    final confirm = find.text('Chấp nhận và chọn công nợ');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, PaymentMethod.credit);
  });
}
