import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

Widget _host(QrScanView view) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: view)),
    );

const _codes = ['CID-1', 'CID-2', 'CID-3'];

void main() {
  testWidgets('demo button hidden when the server sent no codes', (t) async {
    await t.pumpWidget(_host(QrScanView(onCode: (_) {})));
    await t.pump();
    expect(find.textContaining('Quét nhanh'), findsNothing);
  });

  testWidgets('empty quantity scans every code through onCode', (t) async {
    final got = <String>[];
    await t.pumpWidget(_host(QrScanView(onCode: got.add, demoCodes: _codes)));
    await t.pump();
    await t.tap(find.text('Quét nhanh (demo) · còn 3'));
    await t.pump();
    expect(got, _codes);
  });

  testWidgets('entered quantity scans only that many codes', (t) async {
    final got = <String>[];
    await t.pumpWidget(_host(QrScanView(onCode: got.add, demoCodes: _codes)));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'Số thùng'), '2');
    await t.tap(find.text('Quét nhanh (demo) · còn 3'));
    await t.pump();
    expect(got, ['CID-1', 'CID-2']);
  });

  testWidgets('quantity above the remaining count is rejected', (t) async {
    final got = <String>[];
    await t.pumpWidget(_host(QrScanView(onCode: got.add, demoCodes: _codes)));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'Số thùng'), '4');
    await t.tap(find.text('Quét nhanh (demo) · còn 3'));
    await t.pump();
    expect(got, isEmpty);
    expect(find.text('Nhập số thùng từ 1 đến 3.'), findsOneWidget);
  });

  testWidgets('demo count passes the wanted count to the screen handler',
      (t) async {
    int? wanted;
    await t.pumpWidget(_host(QrScanView(
      onCode: (_) {},
      demoCount: 5,
      onDemoScan: (codes, count) async => wanted = count,
    )));
    await t.pump();
    await t.enterText(find.widgetWithText(TextField, 'Số thùng'), '2');
    await t.tap(find.text('Quét nhanh (demo) · còn 5'));
    await t.pump();
    expect(wanted, 2);
  });
}
