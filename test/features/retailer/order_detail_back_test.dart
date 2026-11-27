import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_order_detail_screen.dart';
import 'package:fscm_mobile/shared/routes.dart';

void main() {
  const code = 'DH-000001046';
  final detailPath = AppRoutes.rtOrderDetail(code);

  for (final direct in [true, false]) {
    testWidgets('order header returns to orders with direct=$direct',
        (tester) async {
      final router = GoRouter(
        initialLocation: direct ? detailPath : AppRoutes.rtOrders,
        routes: [
          GoRoute(
            path: AppRoutes.rtOrders,
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push(detailPath),
                child: const Text('Danh sách đơn hàng'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.rtOrderDetailPattern,
            builder: (context, state) => const RtOrderDetailScreen(code: code),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          orderDetailProvider(code)
              .overrideWith((ref) => Completer<Order>().future),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      if (!direct) {
        await tester.tap(find.text('Danh sách đơn hàng'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Danh sách đơn hàng'), findsOneWidget);
      expect(
          router.routeInformationProvider.value.uri.path, AppRoutes.rtOrders);
      expect(tester.takeException(), isNull);
    });
  }
}
