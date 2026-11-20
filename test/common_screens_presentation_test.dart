import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';
import 'package:fscm_mobile/features/common/auth/login_screen.dart';
import 'package:fscm_mobile/features/common/auth/retailer_activation_screen.dart';
import 'package:fscm_mobile/features/common/auth/splash_screen.dart';
import 'package:fscm_mobile/features/common/notifications/notifications_screen.dart';
import 'package:fscm_mobile/features/common/profile/profile_screen.dart';

/// Presentation-only checks for UI.2: layouts must not overflow on a small
/// phone with a large system font, and key actions stay reachable.
class _FakeAuth extends StateNotifier<AuthState> implements AuthController {
  _FakeAuth() : super(const AuthState(status: AuthStatus.unauthenticated));
  int logoutCalls = 0;

  @override
  Future<void> restore() async {}

  @override
  Future<void> logout({bool callServer = true}) async => logoutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotifications extends StateNotifier<AsyncValue<NotificationsState>>
    implements NotificationsController {
  _FakeNotifications(NotificationsState s) : super(AsyncData(s));
  final List<String> read = <String>[];
  int markAll = 0;
  int more = 0;

  @override
  Future<void> markRead(AppNotification n) async => read.add(n.id);

  @override
  Future<void> markAllRead() async => markAll++;

  @override
  Future<void> loadMore() async => more++;

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _smallPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, List<Override> overrides, {double scale = 1.6}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: home,
    ),
  );
}

final _sales = AppUser.fromJson(<String, dynamic>{
  'id': 'u1',
  'fullName': 'Nguyễn Văn An',
  'email': 'an@example.com',
  'role': 'Sales',
  'scope': <String, dynamic>{},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash does not overflow at 360x640 and 1.6x font',
      (tester) async {
    _smallPhone(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(const SplashScreen(),
        [authControllerProvider.overrideWith((ref) => auth)]));
    expect(find.text('FSCM'), findsOneWidget);
    expect(find.text('Hệ thống quản lý chuỗi cung ứng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login stays scrollable with keyboard open and large font',
      (tester) async {
    _smallPhone(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(const LoginScreen(),
        [authControllerProvider.overrideWith((ref) => auth)]));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục'), findsOneWidget);
    await tester.ensureVisible(find.text('Đăng nhập bằng Google'));
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activation keeps 3 steps with progress and no overflow',
      (tester) async {
    _smallPhone(tester);
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(
        const RetailerActivationScreen(identifier: '0909555127'),
        [authControllerProvider.overrideWith((ref) => auth)]));
    await tester.pumpAndSettle();
    expect(find.text('Bước 1/3'), findsOneWidget);
    expect(find.text('Xác nhận tài khoản'), findsOneWidget);
    expect(find.text('Gửi OTP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('notifications', () {
    NotificationsState state({bool hasMore = false}) => NotificationsState(
          local: const <AppNotification>[],
          server: <AppNotification>[
            AppNotification(
                id: 'n1',
                title: 'Đơn đã duyệt',
                text: 'Đơn DH-001 đã được duyệt.',
                createdAt: DateTime(2026, 11, 20, 9, 30)),
            AppNotification(
                id: 'n2',
                text: 'Đã giao hàng.',
                unread: false,
                createdAt: DateTime(2026, 11, 19, 8)),
          ],
          page: 1,
          hasMore: hasMore,
        );

    testWidgets('lists items, marks read on tap and marks all', (tester) async {
      _smallPhone(tester);
      final fake = _FakeNotifications(state(hasMore: true));
      await tester.pumpWidget(_app(const NotificationsScreen(), [
        notificationsProvider.overrideWith((ref) => fake),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Đơn đã duyệt'), findsOneWidget);
      expect(find.text('Đã giao hàng.'), findsOneWidget);
      await tester.tap(find.text('Đơn đã duyệt'));
      await tester.pumpAndSettle();
      expect(fake.read, <String>['n1']);
      await tester.tap(find.text('Đánh dấu đã đọc'));
      expect(fake.markAll, 1);
      await tester.ensureVisible(find.text('Tải thêm'));
      await tester.tap(find.text('Tải thêm'));
      expect(fake.more, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows the empty state', (tester) async {
      _smallPhone(tester);
      final fake = _FakeNotifications(const NotificationsState(
          local: <AppNotification>[],
          server: <AppNotification>[],
          page: 1,
          hasMore: false));
      await tester.pumpWidget(_app(const NotificationsScreen(), [
        notificationsProvider.overrideWith((ref) => fake),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông báo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('profile keeps role actions in order and confirms logout',
      (tester) async {
    _smallPhone(tester);
    tester.view.physicalSize = const Size(360, 900);
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(
        const ProfileScreen(actions: <ProfileAction>[
          ProfileAction(
              label: 'Cửa hàng phụ trách',
              icon: Icons.storefront_outlined,
              route: '/a'),
          ProfileAction(
              label: 'Khuyến mãi',
              icon: Icons.local_offer_outlined,
              route: '/b'),
        ]),
        [
          authControllerProvider.overrideWith((ref) => auth),
          currentUserProvider.overrideWithValue(_sales),
        ],
        scale: 1.0));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('Cửa hàng phụ trách')).dy;
    final second = tester.getTopLeft(find.text('Khuyến mãi')).dy;
    expect(first, lessThan(second));
    await tester.ensureVisible(find.byKey(const Key('btn_logout')));
    await tester.tap(find.byKey(const Key('btn_logout')));
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
