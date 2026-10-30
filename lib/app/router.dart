import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/app/shell/retailer_shell.dart';
import 'package:fscm_mobile/app/shell/sales_shell.dart';
import 'package:fscm_mobile/app/shell/warehouse_shell.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/common/auth/login_screen.dart';
import 'package:fscm_mobile/features/common/auth/splash_screen.dart';
import 'package:fscm_mobile/features/common/notifications/notifications_screen.dart';
import 'package:fscm_mobile/features/common/profile/profile_screen.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaint_form_screen.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaints_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/gifts_screen.dart';
import 'package:fscm_mobile/features/retailer/loyalty/loyalty_screen.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_order_detail_screen.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_orders_screen.dart';
import 'package:fscm_mobile/features/retailer/payments/payments_screen.dart';
import 'package:fscm_mobile/features/retailer/receive/receive_screen.dart';
import 'package:fscm_mobile/features/retailer/scan/rt_scan_screen.dart';
import 'package:fscm_mobile/features/sales/debts/debts_screen.dart';
import 'package:fscm_mobile/features/sales/declare/declarations_screen.dart';
import 'package:fscm_mobile/features/sales/declare/declare_retailer_screen.dart';
import 'package:fscm_mobile/features/sales/home/sales_home_screen.dart';
import 'package:fscm_mobile/features/sales/kpi/kpi_screen.dart';
import 'package:fscm_mobile/features/sales/orders/order_create_screen.dart';
import 'package:fscm_mobile/features/sales/orders/order_detail_screen.dart';
import 'package:fscm_mobile/features/sales/orders/sales_orders_screen.dart';
import 'package:fscm_mobile/features/sales/products/product_list_screen.dart';
import 'package:fscm_mobile/features/sales/products/promotions_screen.dart';
import 'package:fscm_mobile/features/sales/retailers/retailer_list_screen.dart';
import 'package:fscm_mobile/features/sales/scan/sales_scan_screen.dart';
import 'package:fscm_mobile/features/sales/sync/sync_queue_screen.dart';
import 'package:fscm_mobile/features/warehouse/home/wk_home_screen.dart';
import 'package:fscm_mobile/features/warehouse/labels/label_detail_screen.dart';
import 'package:fscm_mobile/features/warehouse/picking/pick_line_screen.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_detail_screen.dart';
import 'package:fscm_mobile/features/warehouse/picking/picking_lists_screen.dart';
import 'package:fscm_mobile/features/warehouse/scan/wk_scan_screen.dart';
import 'package:fscm_mobile/features/warehouse/transfers/transfer_detail_screen.dart';
import 'package:fscm_mobile/features/warehouse/transfers/transfers_screen.dart';
import 'package:fscm_mobile/shared/routes.dart';

/// First screen of each role after login.
String homeRouteFor(UserRole role) {
  switch (role) {
    case UserRole.sales:
      return AppRoutes.salesHome;
    case UserRole.warehouseKeeper:
      return AppRoutes.wkHome;
    case UserRole.retailer:
      return AppRoutes.rtOrders;
    default:
      return AppRoutes.login;
  }
}

/// Path prefix a role may navigate in (roles never see each other's screens).
String _prefixFor(UserRole role) {
  switch (role) {
    case UserRole.sales:
      return '/sales';
    case UserRole.warehouseKeeper:
      return '/wk';
    case UserRole.retailer:
      return '/retailer';
    default:
      return '';
  }
}

/// Pure redirect rule, kept separate so it is easy to test.
///
/// * auth state unknown -> splash (restores the stored session)
/// * signed out -> login
/// * signed in -> role home when on splash/login or in another role's area
String? redirectFor({
  required AuthStatus status,
  required UserRole? role,
  required String location,
}) {
  switch (status) {
    case AuthStatus.unknown:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return location == AppRoutes.login ? null : AppRoutes.login;
    case AuthStatus.authenticated:
      if (role == null || !role.hasMobileShell) return AppRoutes.login;
      if (location == '/' ||
          location == AppRoutes.splash ||
          location == AppRoutes.login) {
        return homeRouteFor(role);
      }
      final prefix = _prefixFor(role);
      final foreign =
          <String>['/sales', '/wk', '/retailer'].where((p) => p != prefix);
      if (foreign.any((p) => location == p || location.startsWith('$p/'))) {
        return homeRouteFor(role);
      }
      return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.status != next.status ||
        previous?.user?.role != next.user?.role) {
      refresh.value++;
    }
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return redirectFor(
        status: auth.status,
        role: auth.user?.role,
        location: state.uri.path,
      );
    },
    routes: <RouteBase>[
      GoRoute(path: AppRoutes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.notifications,
          builder: (c, s) => const NotificationsScreen()),
      ..._salesRoutes(),
      ..._warehouseRoutes(),
      ..._retailerRoutes(),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

// ------------------------------------------------------------------ sales

List<RouteBase> _salesRoutes() => <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => SalesShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.salesHome,
                builder: (c, s) => const SalesHomeScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.salesOrders,
                builder: (c, s) => const SalesOrdersScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.salesScan,
                builder: (c, s) => const SalesScanScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.salesSync,
                builder: (c, s) => const SyncQueueScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.salesAccount,
              builder: (c, s) => const ProfileScreen(actions: <ProfileAction>[
                ProfileAction(
                    label: 'Cửa hàng phụ trách',
                    icon: Icons.storefront_outlined,
                    route: AppRoutes.salesRetailers),
                ProfileAction(
                    label: 'Sản phẩm & tồn kho',
                    icon: Icons.inventory_2_outlined,
                    route: AppRoutes.salesProducts),
                ProfileAction(
                    label: 'Khuyến mãi',
                    icon: Icons.local_offer_outlined,
                    route: AppRoutes.salesPromotions),
                ProfileAction(
                    label: 'Công nợ khách hàng',
                    icon: Icons.account_balance_wallet_outlined,
                    route: AppRoutes.salesDebts),
                ProfileAction(
                    label: 'KPI & xếp hạng',
                    icon: Icons.bar_chart_outlined,
                    route: AppRoutes.salesKpi),
                ProfileAction(
                    label: 'Khai báo cửa hàng mới',
                    icon: Icons.add_business_outlined,
                    route: AppRoutes.salesDeclare),
                ProfileAction(
                    label: 'Yêu cầu đã khai báo',
                    icon: Icons.assignment_outlined,
                    route: AppRoutes.salesDeclarations),
              ]),
            ),
          ]),
        ],
      ),
      GoRoute(
          path: AppRoutes.salesRetailers,
          builder: (c, s) => const RetailerListScreen()),
      GoRoute(
          path: AppRoutes.salesProducts,
          builder: (c, s) => const ProductListScreen()),
      GoRoute(
          path: AppRoutes.salesPromotions,
          builder: (c, s) => const PromotionsScreen()),
      GoRoute(
          path: AppRoutes.salesDebts, builder: (c, s) => const DebtsScreen()),
      GoRoute(path: AppRoutes.salesKpi, builder: (c, s) => const KpiScreen()),
      GoRoute(
          path: AppRoutes.salesDeclare,
          builder: (c, s) => const DeclareRetailerScreen()),
      GoRoute(
          path: AppRoutes.salesDeclarations,
          builder: (c, s) => const DeclarationsScreen()),
      GoRoute(
        path: AppRoutes.salesNewOrderPattern,
        builder: (c, s) => OrderCreateScreen(
            retailerCode: s.pathParameters['retailerCode'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.salesOrderDetailPattern,
        builder: (c, s) =>
            SalesOrderDetailScreen(code: s.pathParameters['code'] ?? ''),
      ),
    ];

// -------------------------------------------------------------- warehouse

List<RouteBase> _warehouseRoutes() => <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            WarehouseShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.wkHome,
                builder: (c, s) => const WkHomeScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.wkPicking,
                builder: (c, s) => const PickingListsScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.wkTransfers,
                builder: (c, s) => const TransfersScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.wkAccount,
              builder: (c, s) => const ProfileScreen(actions: <ProfileAction>[
                ProfileAction(
                    label: 'Phiếu đã xuất kho',
                    icon: Icons.outbox_outlined,
                    route: AppRoutes.wkShipped),
                ProfileAction(
                    label: 'Tra cứu tem',
                    icon: Icons.qr_code_2,
                    route: AppRoutes.wkLabelLookup),
              ]),
            ),
          ]),
        ],
      ),
      GoRoute(path: AppRoutes.wkScan, builder: (c, s) => const WkScanScreen()),
      GoRoute(
        path: AppRoutes.wkShipped,
        builder: (c, s) => const PickingListsScreen(shippedOnly: true),
      ),
      GoRoute(
        path: AppRoutes.wkLabelLookup,
        builder: (c, s) => const WkScanScreen(labelsOnly: true),
      ),
      GoRoute(
        path: AppRoutes.wkPickingDetailPattern,
        builder: (c, s) =>
            PickingDetailScreen(code: s.pathParameters['code'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.wkPickLinePattern,
        builder: (c, s) => PickLineScreen(
          code: s.pathParameters['code'] ?? '',
          lineIndex: int.tryParse(s.pathParameters['index'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: AppRoutes.wkTransferDetailPattern,
        builder: (c, s) =>
            TransferDetailScreen(code: s.pathParameters['code'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.wkLabelPattern,
        builder: (c, s) =>
            LabelDetailScreen(code: s.pathParameters['code'] ?? ''),
      ),
    ];

// --------------------------------------------------------------- retailer

List<RouteBase> _retailerRoutes() => <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            RetailerShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.rtOrders,
                builder: (c, s) => const RtOrdersScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
                path: AppRoutes.rtScan,
                builder: (c, s) => const RtScanScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.rtAccount,
              builder: (c, s) => const ProfileScreen(actions: <ProfileAction>[
                ProfileAction(
                    label: 'Thanh toán & công nợ',
                    icon: Icons.payments_outlined,
                    route: AppRoutes.rtPayments),
                ProfileAction(
                    label: 'Thẻ tích điểm',
                    icon: Icons.stars_outlined,
                    route: AppRoutes.rtLoyalty),
                ProfileAction(
                    label: 'Đổi quà',
                    icon: Icons.card_giftcard,
                    route: AppRoutes.rtGifts),
                ProfileAction(
                    label: 'Khiếu nại',
                    icon: Icons.report_gmailerrorred_outlined,
                    route: AppRoutes.rtComplaints),
              ]),
            ),
          ]),
        ],
      ),
      GoRoute(
          path: AppRoutes.rtPayments,
          builder: (c, s) => const PaymentsScreen()),
      GoRoute(
          path: AppRoutes.rtLoyalty, builder: (c, s) => const LoyaltyScreen()),
      GoRoute(path: AppRoutes.rtGifts, builder: (c, s) => const GiftsScreen()),
      GoRoute(
          path: AppRoutes.rtComplaints,
          builder: (c, s) => const ComplaintsScreen()),
      GoRoute(
        path: AppRoutes.rtComplaintNew,
        builder: (c, s) =>
            ComplaintFormScreen(orderCode: s.uri.queryParameters['order']),
      ),
      GoRoute(
        path: AppRoutes.rtOrderDetailPattern,
        builder: (c, s) =>
            RtOrderDetailScreen(code: s.pathParameters['code'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.rtReceivePattern,
        builder: (c, s) =>
            RtReceiveScreen(code: s.pathParameters['code'] ?? ''),
      ),
    ];
