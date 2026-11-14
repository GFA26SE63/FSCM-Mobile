import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/shared/widgets/order_quantity_field.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';

void main() {
  Future<void> showFooter(WidgetTester tester, double width, {
    double scale = 1,
    bool selected = true,
    VoidCallback? onRemove,
  }) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Align(alignment: Alignment.topLeft, child: SizedBox(
        width: width,
        child: OrderQuantityField(
          label: 'Số lượng (thùng)',
          showRemove: selected,
          onRemove: onRemove,
          control: QuantityStepper(editable: true, value: selected ? 150 : 0, onChanged: (_) {}),
        ),
      )),
    ))));
    await tester.pump();
  }

  testWidgets('quantity is flush right, removal has its own line and no reserved X slot', (tester) async {
    var removed = false;
    await showFooter(tester, 340, onRemove: () => removed = true);
    final footer = tester.getRect(find.byType(OrderQuantityField));
    final control = tester.getRect(find.byType(QuantityStepper));
    final label = tester.getRect(find.text('Số lượng (thùng)'));
    final remove = tester.getRect(find.widgetWithText(TextButton, 'Bỏ khỏi giỏ'));
    expect(control.right, closeTo(footer.right, 0.1));
    expect(label.right, lessThan(control.left));
    expect(remove.top, greaterThanOrEqualTo(control.bottom));
    expect(remove.right, closeTo(footer.right, 0.1));
    await tester.tap(find.text('Bỏ khỏi giỏ'));
    expect(removed, isTrue);
    expect(tester.takeException(), isNull);
    await showFooter(tester, 340, selected: false);
    expect(find.text('Bỏ khỏi giỏ'), findsNothing);
    expect(tester.getRect(find.byType(QuantityStepper)).right, closeTo(footer.right, 0.1));
  });

  testWidgets('narrow cards and larger text put the caption above without squeezing it', (tester) async {
    for (final scale in [1.0, 1.5]) {
      await showFooter(tester, 250, scale: scale);
      final label = tester.getRect(find.text('Số lượng (thùng)'));
      final control = tester.getRect(find.byType(QuantityStepper));
      expect(label.bottom, lessThan(control.top));
      expect(control.right, closeTo(250, 0.1));
      expect(tester.takeException(), isNull);
    }
  });
}
