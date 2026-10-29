import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/mock/mock_api.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/common/auth/login_screen.dart';
import 'package:fscm_mobile/features/common/profile/profile_screen.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/authorize.dart';

class _InMemoryTokenStore extends TokenStore {
  Map<String, dynamic>? _memory;

  @override
  String? get accessToken => _memory?['accessToken'] as String?;

  @override
  String? get refreshToken => _memory?['refreshToken'] as String?;

  @override
  Map<String, dynamic>? get cachedSession => _memory;

  @override
  Future<Map<String, dynamic>?> load() async => _memory;

  @override
  Future<void> save(Map<String, dynamic> session) async {
    _memory = Map<String, dynamic>.of(session);
  }

  @override
  Future<void> clear() async {
    _memory = null;
  }
}

class _FakeAppDatabase extends Fake implements AppDatabase {
  @override
  Future<void> clearCache({bool keepQueue = true}) async {}
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer({MockStore? store}) {
    final tokenStore = _InMemoryTokenStore();
    final mockStore = store ?? MockStore();
    return ProviderContainer(
      overrides: <Override>[
        tokenStoreProvider.overrideWithValue(tokenStore),
        apiTransportProvider.overrideWith(
          (_) => MockApi(store: mockStore, latencyMs: 0),
        ),
        appDatabaseProvider.overrideWithValue(_FakeAppDatabase()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        offlineQueueProvider.overrideWith((ref) => Future.value(<OfflineOrder>[])),
      ],
    );
  }

  group('Login & Authentication', () {
    testWidgets('LoginScreen starts with blank inputs and logs in Sales user',
        (WidgetTester tester) async {
      final container = createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.text('FSCM'), findsOneWidget);
      expect(
        find.text('Đặt hàng, soạn hàng và nhận hàng hạn sử dụng ngắn.'),
        findsOneWidget,
      );
      expect(find.text('Nhân viên'), findsOneWidget);
      expect(find.text('Khách hàng'), findsOneWidget);
      expect(find.text('Đăng nhập với Microsoft'), findsOneWidget);

      // Verify input fields are initially blank for real accounts
      final emailField = tester.widget<TextField>(
        find.byKey(const Key('input_staff_email')),
      );
      expect(emailField.controller?.text, isEmpty);

      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('input_staff_password')),
      );
      expect(passwordField.controller?.text, isEmpty);

      // Enter real credentials
      await tester.enterText(
        find.byKey(const Key('input_staff_email')),
        'an.nv@fscm.vn',
      );
      await tester.enterText(
        find.byKey(const Key('input_staff_password')),
        '12345678',
      );
      await tester.tap(find.byKey(const Key('btn_staff_login')));
      await tester.pumpAndSettle();

      final authState = container.read(authControllerProvider);
      expect(authState.isAuthenticated, isTrue);
      expect(authState.user?.email, 'an.nv@fscm.vn');
      expect(authState.user?.role, UserRole.sales);
    });

    testWidgets('LoginScreen shows error banner on invalid credentials (401)',
        (WidgetTester tester) async {
      final container = createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('input_staff_email')),
        'an.nv@fscm.vn',
      );
      await tester.enterText(
        find.byKey(const Key('input_staff_password')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const Key('btn_staff_login')));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.textContaining('không đúng'), findsOneWidget);
    });

    testWidgets('LoginScreen rejects Portal-only role (Admin) on mobile',
        (WidgetTester tester) async {
      final container = createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('input_staff_email')),
        'khoa.pm@fscm.vn',
      );
      await tester.enterText(
        find.byKey(const Key('input_staff_password')),
        '12345678',
      );
      await tester.tap(find.byKey(const Key('btn_staff_login')));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.textContaining('Không có quyền truy cập'), findsOneWidget);
    });
  });

  group('Role-Based Authorization & Route Guards (F10-MB)', () {
    test('homeRouteFor maps role to designated shell', () {
      expect(homeRouteFor(UserRole.sales), AppRoutes.salesHome);
      expect(homeRouteFor(UserRole.warehouseKeeper), AppRoutes.wkHome);
      expect(homeRouteFor(UserRole.retailer), AppRoutes.rtOrders);
      expect(homeRouteFor(UserRole.admin), AppRoutes.login);
      expect(homeRouteFor(UserRole.operator), AppRoutes.login);
    });

    test('redirectFor redirects unauthenticated users to login', () {
      expect(
        redirectFor(
          status: AuthStatus.unauthenticated,
          role: null,
          location: AppRoutes.salesHome,
        ),
        AppRoutes.login,
      );
      expect(
        redirectFor(
          status: AuthStatus.unauthenticated,
          role: null,
          location: AppRoutes.login,
        ),
        isNull,
      );
    });

    test('redirectFor redirects unknown auth status to splash', () {
      expect(
        redirectFor(
          status: AuthStatus.unknown,
          role: null,
          location: AppRoutes.salesHome,
        ),
        AppRoutes.splash,
      );
      expect(
        redirectFor(
          status: AuthStatus.unknown,
          role: null,
          location: AppRoutes.splash,
        ),
        isNull,
      );
    });

    test('redirectFor prevents roles from accessing other shells', () {
      // Sales trying to access Warehouse routes is redirected to /sales/home
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.sales,
          location: AppRoutes.wkHome,
        ),
        AppRoutes.salesHome,
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.sales,
          location: AppRoutes.rtOrders,
        ),
        AppRoutes.salesHome,
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.sales,
          location: AppRoutes.salesOrders,
        ),
        isNull,
      );

      // Warehouse keeper trying to access Sales or Retailer routes
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.warehouseKeeper,
          location: AppRoutes.salesHome,
        ),
        AppRoutes.wkHome,
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.warehouseKeeper,
          location: AppRoutes.wkPicking,
        ),
        isNull,
      );

      // Retailer trying to access Sales or Warehouse routes
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.retailer,
          location: AppRoutes.salesHome,
        ),
        AppRoutes.rtOrders,
      );
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.retailer,
          location: AppRoutes.rtPayments,
        ),
        isNull,
      );

      // Common routes (e.g. notifications) are accessible by all authorized roles
      expect(
        redirectFor(
          status: AuthStatus.authenticated,
          role: UserRole.sales,
          location: AppRoutes.notifications,
        ),
        isNull,
      );
    });

    test('AppUser scope permission checks', () {
      const salesUser = AppUser(
        id: 'U1',
        fullName: 'Sales Rep',
        role: UserRole.sales,
        salesGroup: 'Q12-A',
        areaCode: 'Q12',
        scope: UserScope(
          salesGroupIds: <String>['Q12-A', 'Q12-B'],
          regionIds: <String>['Q12'],
        ),
      );

      expect(salesUser.canAccessSalesGroup('Q12-A'), isTrue);
      expect(salesUser.canAccessSalesGroup('Q12-B'), isTrue);
      expect(salesUser.canAccessSalesGroup('Q1'), isFalse);
      expect(salesUser.canAccessRegion('Q12'), isTrue);
      expect(salesUser.canAccessWarehouse('WH-TA'), isFalse);

      const wkUser = AppUser(
        id: 'U2',
        fullName: 'Thủ kho',
        role: UserRole.warehouseKeeper,
        warehouseCode: 'WH-TA',
        scope: UserScope(warehouseIds: <String>['WH-TA']),
      );

      expect(wkUser.canAccessWarehouse('WH-TA'), isTrue);
      expect(wkUser.canAccessWarehouse('WH-TD'), isFalse);
      expect(wkUser.canAccessSalesGroup('Q12-A'), isFalse);
    });

    testWidgets('Authorize widget renders content only for permitted roles',
        (WidgetTester tester) async {
      final container = createContainer();
      addTearDown(container.dispose);

      // Login as Sales
      await container
          .read(authControllerProvider.notifier)
          .login('an.nv@fscm.vn', '12345678');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  Authorize(
                    allowedRoles: <UserRole>[UserRole.sales],
                    child: Text('Sales Content'),
                  ),
                  Authorize(
                    allowedRoles: <UserRole>[UserRole.warehouseKeeper],
                    fallback: Text('Access Denied for Warehouse'),
                    child: Text('Warehouse Content'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sales Content'), findsOneWidget);
      expect(find.text('Warehouse Content'), findsNothing);
      expect(find.text('Access Denied for Warehouse'), findsOneWidget);
    });
  });

  group('Logout & Session Invalidation', () {
    test('Logout clears session, token store, and cache', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // 1. Login
      final ok = await container
          .read(authControllerProvider.notifier)
          .login('an.nv@fscm.vn', '12345678');
      expect(ok, isTrue);
      expect(container.read(tokenStoreProvider).accessToken, isNotNull);
      expect(container.read(tokenStoreProvider).refreshToken, isNotNull);
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      // 2. Logout
      await container.read(authControllerProvider.notifier).logout();

      // 3. Verify wiped
      expect(container.read(tokenStoreProvider).accessToken, isNull);
      expect(container.read(tokenStoreProvider).refreshToken, isNull);
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    testWidgets('ProfileScreen logout button opens confirm dialog and logs out',
        (WidgetTester tester) async {
      final container = createContainer();
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .login('an.nv@fscm.vn', '12345678');
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.byKey(const Key('btn_logout')), findsOneWidget);

      // Tap logout button
      await tester.tap(find.byKey(const Key('btn_logout')));
      await tester.pumpAndSettle();

      // Verify confirm dialog appears
      expect(find.text('Đăng xuất?'), findsOneWidget);
      expect(find.text('Bạn sẽ cần đăng nhập lại để tiếp tục.'), findsOneWidget);

      // Tap confirm "Đăng xuất" button in dialog
      await tester.tap(find.text('Đăng xuất').last);
      await tester.pumpAndSettle();

      // Verify user is logged out
      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(container.read(tokenStoreProvider).accessToken, isNull);
      expect(container.read(tokenStoreProvider).refreshToken, isNull);
    });

    test('verifySessionOnResume logs out if user is deactivated on server',
        () async {
      final mockStore = MockStore();
      final container = createContainer(store: mockStore);
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .login('an.nv@fscm.vn', '12345678');
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);

      // Simulate admin deactivating user on server
      final userIndex =
          mockStore.users.indexWhere((u) => u.email == 'an.nv@fscm.vn');
      mockStore.users[userIndex] = MockUser(
        id: mockStore.users[userIndex].id,
        fullName: mockStore.users[userIndex].fullName,
        email: mockStore.users[userIndex].email,
        phone: mockStore.users[userIndex].phone,
        role: mockStore.users[userIndex].role,
        isActive: false, // Deactivated!
      );

      // Trigger app resume check (§3.3)
      await container
          .read(authControllerProvider.notifier)
          .verifySessionOnResume();

      expect(container.read(authControllerProvider).isAuthenticated, isFalse);
      expect(
        container.read(authControllerProvider).error,
        contains('vô hiệu hóa'),
      );
      expect(container.read(tokenStoreProvider).accessToken, isNull);
    });
  });
}
