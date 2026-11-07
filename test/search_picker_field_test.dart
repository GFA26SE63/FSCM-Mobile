import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/shared/widgets/search_picker_field.dart';

void main() {
  testWidgets(
      'searches code and unaccented name, preserves selection on cancel',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SearchPickerField<String>(
      label: 'Sản phẩm',
      options: const ['SKU001 · Sữa tươi', 'SKU002 · Sữa chua'],
      labelOf: (v) => v,
      onChanged: (v) => selected = v,
    ))));
    await tester.tap(find.text('Tìm theo mã hoặc tên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sua tuoi');
    await tester.pumpAndSettle();
    expect(find.text('SKU002 · Sữa chua'), findsNothing);
    await tester.tap(find.text('SKU001 · Sữa tươi'));
    await tester.pumpAndSettle();
    expect(selected, 'SKU001 · Sữa tươi');
    await tester.tap(find.text('SKU001 · Sữa tươi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SKU002');
    await tester.pumpAndSettle();
    expect(find.text('SKU002 · Sữa chua'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unknown');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy kết quả.'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(selected, 'SKU001 · Sữa tươi');
    expect(find.text('SKU001 · Sữa tươi'), findsOneWidget);
  });
}
