import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';

void main() {
  testWidgets('typed cartons respect the configured step and maximum; buttons recover invalid input', (tester) async {
    var quantity = 10;
    var valid = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, update) => QuantityStepper(
        editable: true,
        value: quantity,
        step: 10,
        max: 200,
        onValidationChanged: (value) => valid = value,
        onChanged: (value) => update(() => quantity = value),
      ),
    ))));
    await tester.enterText(find.byType(TextField), '150');
    await tester.pump();
    expect(quantity, 150);
    expect(valid, isTrue);
    await tester.enterText(find.byType(TextField), '153');
    await tester.pump();
    expect(quantity, 150);
    expect(valid, isFalse);
    expect(find.text('Bội 10 thùng'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '210');
    await tester.pump();
    expect(quantity, 150);
    expect(valid, isFalse);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(quantity, 160);
    expect(valid, isTrue);
    expect(find.widgetWithText(TextField, '160'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(valid, isFalse);
    expect(quantity, 160);
  });

  testWidgets('busy controls cannot edit and warehouse steppers retain their existing non-editable default', (tester) async {
    var changes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: QuantityStepper(
      value: 1, enabled: false, editable: true, onChanged: (_) => changes++,
    ))));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed, isNull);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: QuantityStepper(
      value: 1, min: 1, onChanged: (_) => changes++,
    ))));
    expect(find.byType(TextField), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove)).onPressed, isNull);
    await tester.tap(find.byIcon(Icons.add));
    expect(changes, 1);
  });

  testWidgets('editable quantity uses a single group with flat buttons and a borderless field', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: QuantityStepper(
      value: 150000, editable: true, onChanged: (_) {}, max: 1000000,
    ))));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.border, InputBorder.none);
    final minus = tester.getRect(find.widgetWithIcon(IconButton, Icons.remove));
    final input = tester.getRect(find.byType(TextField));
    final plus = tester.getRect(find.widgetWithIcon(IconButton, Icons.add));
    expect(minus.right, lessThanOrEqualTo(input.left));
    expect(input.right, lessThanOrEqualTo(plus.left));
    expect(tester.getSize(find.byType(QuantityStepper)).width, 168);
    expect(tester.takeException(), isNull);
  });
}
