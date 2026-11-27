import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

Widget _host(QrScanView view) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: view)),
    );

void main() {
  testWidgets('demo button hidden when the server sent no codes', (t) async {
    await t.pumpWidget(_host(QrScanView(onCode: (_) {})));
    await t.pump();
    expect(find.textContaining('Quét nhanh'), findsNothing);
  });

  testWidgets('demo button feeds every code through onCode', (t) async {
    final got = <String>[];
    await t.pumpWidget(
        _host(QrScanView(onCode: got.add, demoCodes: const ['CID-1', 'CID-2'])));
    await t.pump();
    await t.tap(find.text('Quét nhanh 2 mã (demo)'));
    await t.pump();
    expect(got, ['CID-1', 'CID-2']);
  });

  testWidgets('demo count shows the button before codes are fetched', (t) async {
    List<String>? sent;
    await t.pumpWidget(_host(QrScanView(
      onCode: (_) {},
      demoCount: 3,
      onDemoScan: (codes) async => sent = codes,
    )));
    await t.pump();
    await t.tap(find.text('Quét nhanh 3 mã (demo)'));
    await t.pump();
    expect(sent, isEmpty);
  });
}
