import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/remote/order_configuration_api.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

Widget _host(bool enabled, List<String> codes, List<String> got) => ProviderScope(
      overrides: [demoFastScanProvider.overrideWith((ref) async => enabled)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QrScanView(onCode: got.add, demoCodes: codes),
          ),
        ),
      ),
    );

void main() {
  testWidgets('demo button hidden while the admin switch is off', (t) async {
    await t.pumpWidget(_host(false, const ['CID-1'], []));
    await t.pump();
    expect(find.textContaining('Quét nhanh'), findsNothing);
  });

  testWidgets('demo button hidden when no codes are left', (t) async {
    await t.pumpWidget(_host(true, const [], []));
    await t.pump();
    expect(find.textContaining('Quét nhanh'), findsNothing);
  });

  testWidgets('demo button feeds every code through onCode', (t) async {
    final got = <String>[];
    await t.pumpWidget(_host(true, const ['CID-1', 'CID-2'], got));
    await t.pump();
    await t.tap(find.text('Quét nhanh 2 mã (demo)'));
    await t.pump();
    expect(got, ['CID-1', 'CID-2']);
  });
}
