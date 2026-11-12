import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/common/auth/login_screen.dart';

class _FakeAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _FakeAuthController({String? error})
      : super(AuthState(status: AuthStatus.unauthenticated, error: error));

  String? lastIdentifier;
  String? lastPassword;
  int loginCalls = 0;
  int googleCalls = 0;
  bool returnSuccess = true;

  @override
  Future<bool> login(String phone, String password) async {
    loginCalls++;
    lastIdentifier = phone;
    lastPassword = password;
    return returnSuccess;
  }

  @override
  Future<bool> loginWithGoogle() async {
    googleCalls++;
    return returnSuccess;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('renders both tabs and defaults to Staff tab', (tester) async {
    final authController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhân viên'), findsOneWidget);
    expect(find.text('Khách hàng'), findsOneWidget);

    // Initial tab is Staff (shows Email, not Số điện thoại)
    expect(find.byKey(const ValueKey('staff_email_field')), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer_phone_field')), findsNothing);
    expect(find.text('Số điện thoại'), findsNothing);
    expect(find.text('Để trống nếu đăng nhập lần đầu.'), findsNothing);
    expect(find.byKey(const ValueKey('password_field')), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
  });

  testWidgets('switches to Customer tab without API call and shows customer fields',
      (tester) async {
    final authController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Type password on staff tab
    await tester.enterText(
        find.byKey(const ValueKey('password_field')), 'secret123');
    await tester.pump();

    // Tap Customer tab
    await tester.tap(find.byKey(const ValueKey('tab_customer')));
    await tester.pumpAndSettle();

    // No login request fired
    expect(authController.loginCalls, 0);

    // Now shows Customer fields
    expect(find.byKey(const ValueKey('customer_phone_field')), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Để trống nếu đăng nhập lần đầu.'), findsNothing);
    expect(find.byKey(const ValueKey('staff_email_field')), findsNothing);

    // Password retained
    final passwordField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('password_field')));
    expect(passwordField.controller?.text, 'secret123');

    // Switch back to Staff tab
    await tester.tap(find.byKey(const ValueKey('tab_staff')));
    await tester.pumpAndSettle();

    expect(authController.loginCalls, 0);
    expect(find.byKey(const ValueKey('staff_email_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer_phone_field')), findsNothing);
  });

  testWidgets('validates email on Staff tab and submits with email',
      (tester) async {
    final authController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Empty email submission
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(authController.loginCalls, 0);

    // Invalid email submission
    await tester.enterText(
        find.byKey(const ValueKey('staff_email_field')), 'invalid-email');
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập email hợp lệ'), findsOneWidget);
    expect(authController.loginCalls, 0);

    // Valid email and password submission
    await tester.enterText(
        find.byKey(const ValueKey('staff_email_field')), 'an.nv@fscm.vn');
    await tester.enterText(
        find.byKey(const ValueKey('password_field')), 'pass1234');
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();

    expect(authController.loginCalls, 1);
    expect(authController.lastIdentifier, 'an.nv@fscm.vn');
    expect(authController.lastPassword, 'pass1234');
  });

  testWidgets('validates phone on Customer tab and submits with phone',
      (tester) async {
    final authController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Customer tab
    await tester.tap(find.byKey(const ValueKey('tab_customer')));
    await tester.pumpAndSettle();

    // Empty phone
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    expect(authController.loginCalls, 0);

    // Invalid phone
    await tester.enterText(
        find.byKey(const ValueKey('customer_phone_field')), '12345');
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số điện thoại hợp lệ (10 chữ số, bắt đầu bằng 0)'),
        findsOneWidget);
    expect(authController.loginCalls, 0);

    // Valid phone (starts with 0, 10 digits)
    await tester.enterText(
        find.byKey(const ValueKey('customer_phone_field')), '0909555127');
    await tester.enterText(
        find.byKey(const ValueKey('password_field')), '12345678');
    await tester.tap(find.byKey(const ValueKey('login_submit_button')));
    await tester.pumpAndSettle();

    expect(authController.loginCalls, 1);
    expect(authController.lastIdentifier, '0909555127');
    expect(authController.lastPassword, '12345678');
  });

  testWidgets('Google login button delegates to auth controller on both tabs',
      (tester) async {
    final authController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => authController),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Google login on Staff tab
    await tester.tap(find.byKey(const ValueKey('google_login_button')));
    await tester.pumpAndSettle();
    expect(authController.googleCalls, 1);

    // Switch to Customer tab
    await tester.tap(find.byKey(const ValueKey('tab_customer')));
    await tester.pumpAndSettle();

    // Google login on Customer tab
    await tester.tap(find.byKey(const ValueKey('google_login_button')));
    await tester.pumpAndSettle();
    expect(authController.googleCalls, 2);
  });
}

