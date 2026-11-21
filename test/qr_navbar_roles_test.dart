import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/app/shell/retailer_shell.dart';
import 'package:fscm_mobile/app/shell/sales_shell.dart';
import 'package:fscm_mobile/app/shell/warehouse_shell.dart';
import 'package:fscm_mobile/shared/routes.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  Widget Function(StatefulNavigationShell) shell,
  List<String> paths,
) async {
  final router = GoRouter(
    initialLocation: paths.first,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (_, __, s) => shell(s),
        branches: <StatefulShellBranch>[
          for (final p in paths)
            StatefulShellBranch(routes: <RouteBase>[
              GoRoute(
                path: p,
                builder: (_, __) => Scaffold(body: Text('Page $p')),
              ),
            ]),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

int _selected(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

Future<void> _tapThroughAll(
    WidgetTester tester, List<String> labels, List<String> paths) async {
  for (var i = labels.length - 1; i >= 0; i--) {
    await tester.tap(find.text(labels[i]));
    await tester.pumpAndSettle();
    expect(_selected(tester), i);
    expect(find.text('Page ${paths[i]}'), findsOneWidget);
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Sales navbar has no QR tab and tabs switch correctly',
      (tester) async {
    final paths = <String>[
      AppRoutes.salesHome,
      AppRoutes.salesOrders,
      AppRoutes.salesSync,
      AppRoutes.salesAccount,
    ];
    await _pump(tester, (s) => SalesShell(navigationShell: s), paths);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Quét QR'), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    await _tapThroughAll(
        tester, ['Trang chủ', 'Đơn hàng', 'Đồng bộ', 'Tài khoản'], paths);
  });

  testWidgets('Warehouse navbar has no QR tab and tabs switch correctly',
      (tester) async {
    final paths = <String>[
      AppRoutes.wkHome,
      AppRoutes.wkPicking,
      AppRoutes.wkAccount,
    ];
    await _pump(tester, (s) => WarehouseShell(navigationShell: s), paths);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Quét theo phiếu'), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    await _tapThroughAll(tester, ['Trang chủ', 'Nhập/Xuất', 'Tài khoản'], paths);
  });

  testWidgets('Retailer navbar keeps the QR tab', (tester) async {
    final paths = <String>[
      AppRoutes.rtOrders,
      AppRoutes.rtScan,
      AppRoutes.rtAccount,
    ];
    await _pump(tester, (s) => RetailerShell(navigationShell: s), paths);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Quét QR'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    await _tapThroughAll(tester, ['Đơn hàng', 'Quét QR', 'Tài khoản'], paths);
  });

  test('Sales scan stays a standalone route outside the shell', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final routes = container.read(routerProvider).configuration.routes;
    expect(
      routes.whereType<GoRoute>().any((r) => r.path == AppRoutes.salesScan),
      isTrue,
    );
    for (final shell in routes.whereType<StatefulShellRoute>()) {
      for (final b in shell.branches) {
        expect(
          b.routes.whereType<GoRoute>().any((r) => r.path == AppRoutes.salesScan),
          isFalse,
        );
      }
    }
  });
}
