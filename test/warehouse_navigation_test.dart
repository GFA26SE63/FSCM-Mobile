import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/app/shell/warehouse_shell.dart';
import 'package:fscm_mobile/shared/routes.dart';

void main() {
  for (final width in <double>[320, 800]) {
    testWidgets('warehouse navigation and scan work at width $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: AppRoutes.wkHome,
        routes: <RouteBase>[
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => WarehouseShell(navigationShell: shell),
            branches: <StatefulShellBranch>[
              for (final path in <String>[
                AppRoutes.wkHome,
                AppRoutes.wkPicking,
                AppRoutes.wkAccount,
              ])
                StatefulShellBranch(routes: <RouteBase>[
                  GoRoute(
                    path: path,
                    builder: (_, __) => Scaffold(body: Text('Page $path')),
                  ),
                ]),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text('Quét theo phiếu'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      for (final entry in <String, String>{
        'Nhập/Xuất': AppRoutes.wkPicking,
        'Tài khoản': AppRoutes.wkAccount,
        'Trang chủ': AppRoutes.wkHome,
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text('Page ${entry.value}'), findsOneWidget);
        expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            entry.key == 'Nhập/Xuất'
                ? 1
                : entry.key == 'Tài khoản'
                    ? 2
                    : 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
