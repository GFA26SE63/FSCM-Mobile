import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/common/auth/login_screen.dart';

class _FakeAuthController extends StateNotifier<AuthState> implements AuthController {
  _FakeAuthController() : super(const AuthState(status: AuthStatus.unauthenticated));

  String? lastIdentifier;
  String? lastPassword;
  int lookupCalls = 0;
  int loginCalls = 0;
  int googleCalls = 0;

  @override
  Future<bool> requiresActivation(String identifier) async {
    lookupCalls++;
    lastIdentifier = identifier;
    return false;
  }

  @override
  Future<bool> login(String identifier, String password) async {
    loginCalls++;
    lastIdentifier = identifier;
    lastPassword = password;
    return true;
  }

  @override
  Future<bool> loginWithGoogle() async {
    googleCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpLogin(WidgetTester tester, _FakeAuthController controller) =>
    tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: LoginScreen()),
    ));

void main() {
  testWidgets('starts with one identifier field and no password', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller);
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc Số điện thoại'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsNothing);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
  });

  testWidgets('validates identifier before account lookup', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập email hoặc số điện thoại hợp lệ'), findsOneWidget);
    expect(controller.lookupCalls, 0);
  });

  testWidgets('valid account advances to the password step then logs in', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller);
    await tester.enterText(find.byType(TextFormField).first, 'an.nv@fscm.vn');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(controller.lookupCalls, 1);
    expect(controller.lastIdentifier, 'an.nv@fscm.vn');
    expect(find.text('Mật khẩu'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'Pass@123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(controller.loginCalls, 1);
    expect(controller.lastPassword, 'Pass@123');
  });

  testWidgets('accepts a Vietnamese mobile number as the identifier', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller);
    await tester.enterText(find.byType(TextFormField).first, '0909555127');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(controller.lookupCalls, 1);
    expect(controller.lastIdentifier, '0909555127');
    expect(find.text('Mật khẩu'), findsOneWidget);
  });

  testWidgets('Google login delegates to the auth controller', (tester) async {
    final controller = _FakeAuthController();
    await _pumpLogin(tester, controller);
    await tester.tap(find.text('Đăng nhập bằng Google'));
    await tester.pumpAndSettle();
    expect(controller.googleCalls, 1);
  });
}
