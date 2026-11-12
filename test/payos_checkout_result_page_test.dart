import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/shared/widgets/payos_checkout_result_page.dart';

void main() {
  testWidgets('PayOS handoff refreshes immediately after returning to app',
      (tester) async {
    var opened = 0;
    var refreshed = 0;
    var terminal = 0;

    await tester.pumpWidget(MaterialApp(
      home: PayOsCheckoutResultPage(
        checkoutUrl: 'https://pay.payos.vn/checkout-1',
        initial: const PayOsCheckoutSnapshot(
          state: PayOsCheckoutState.pending,
          amount: 1000000,
          summary: 'Đơn DH-000001',
        ),
        refresh: () async {
          refreshed++;
          return const PayOsCheckoutSnapshot(
            state: PayOsCheckoutState.paid,
            amount: 1000000,
            summary: 'Đơn DH-000001',
          );
        },
        onTerminal: () => terminal++,
        openUrl: (_) async {
          opened++;
          return true;
        },
        homeRoute: '/home',
        reviewRoute: '/order',
        reviewLabel: 'Xem lại đơn hàng',
      ),
    ));
    await tester.pump();

    expect(opened, 1);
    expect(find.text('Đang chờ PayOS xác nhận'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(refreshed, 1);
    expect(terminal, 1);
    expect(find.text('Thanh toán thành công'), findsOneWidget);
  });
}
