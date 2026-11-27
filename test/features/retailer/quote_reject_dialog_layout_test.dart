import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/retailer_order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/widgets/retailer_quote_panel.dart';

import '../../fixtures/retailer_order_fixture.dart';

// MOB-03: the app theme gives FilledButton an infinite minimum width, so the
// AlertDialog OverflowBar always stacked "Quay lại" directly on "Từ chối".
class _Actions extends RetailerOrderActions {
  _Actions(Ref ref) : super(ref, 'u');
  final reasons = <String>[];
  @override
  Future<SalesOrderQuote> reject(
      Order order, SalesOrderQuote quote, String reason) async {
    reasons.add(reason);
    return quote;
  }
}

Future<_Actions> _open(WidgetTester tester,
    {double width = 411, double scale = 1, double keyboard = 0}) async {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  late _Actions actions;
  final order = retailerOrderFixture();
  await tester.pumpWidget(ProviderScope(
      overrides: [
        orderQuotesProvider(order.id)
            .overrideWith((ref) async => [retailerQuoteFixture()]),
        retailerOrderActionsProvider
            .overrideWith((ref) => actions = _Actions(ref)),
      ],
      child: MaterialApp(
          theme: buildAppTheme(),
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: RetailerQuotePanel(order: order))))));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Từ chối báo giá'));
  await tester.tap(find.text('Từ chối báo giá'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  return actions;
}

Finder _back() => find.widgetWithText(OutlinedButton, 'Quay lại');
Finder _reject() => find.widgetWithText(FilledButton, 'Từ chối');

void _expectSeparated(WidgetTester tester) {
  final reject = tester.getRect(_reject());
  final back = tester.getRect(_back());
  expect(reject.overlaps(back), isFalse);
  expect(back.top - reject.bottom, greaterThanOrEqualTo(8));
  final dialog = tester.getRect(find.byType(AlertDialog));
  for (final r in [reject, back]) {
    expect(r.left, greaterThanOrEqualTo(dialog.left));
    expect(r.right, lessThanOrEqualTo(dialog.right));
  }
}

void main() {
  for (final (width, scale) in [(411.0, 1.0), (320.0, 1.0), (320.0, 1.6)]) {
    testWidgets('actions are separated at ${width}dp × $scale', (tester) async {
      await _open(tester, width: width, scale: scale);
      _expectSeparated(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard open + long reason: both actions reachable',
      (tester) async {
    final actions = await _open(tester, width: 320, scale: 1.3, keyboard: 320);
    await tester.enterText(find.byType(TextFormField),
        'Giá cao hơn thỏa thuận ban đầu với nhà phân phối. ' * 6);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(_back());
    await tester.pumpAndSettle();
    _expectSeparated(tester);
    await tester.tap(_reject());
    await tester.pumpAndSettle();
    expect(actions.reasons, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Quay lại closes without submitting', (tester) async {
    final actions = await _open(tester);
    await tester.tap(_back());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(actions.reasons, isEmpty);
  });

  testWidgets('empty reason is still rejected by validation', (tester) async {
    final actions = await _open(tester);
    await tester.tap(_reject());
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(actions.reasons, isEmpty);
  });

  testWidgets('double tap on Từ chối submits once', (tester) async {
    final actions = await _open(tester);
    await tester.enterText(find.byType(TextFormField), 'Sai giá');
    await tester.tap(_reject());
    await tester.tap(_reject(), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(actions.reasons, ['Sai giá']);
  });
}
