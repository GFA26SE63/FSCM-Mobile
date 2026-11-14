import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/common/auth/login_screen.dart';
import 'package:fscm_mobile/features/common/auth/splash_screen.dart';
import 'package:fscm_mobile/shared/widgets/fscm_logo.dart';

class _FakeAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _FakeAuthController()
      : super(const AuthState(status: AuthStatus.unauthenticated));

  @override
  Future<void> restore() async {}

  @override
  Future<bool> requiresActivation(String identifier) async => false;

  @override
  Future<bool> login(String identifier, String password) async => true;

  @override
  Future<bool> loginWithGoogle() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FscmLogo renders Image.asset with new official logo',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FscmLogo(size: 64, borderRadius: 16),
        ),
      ),
    );

    expect(find.byType(FscmLogo), findsOneWidget);
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.image, isA<AssetImage>());
    final assetImage = imageWidget.image as AssetImage;
    expect(assetImage.assetName, equals('assets/images/fscm_logo.png'));
  });

  testWidgets('SplashScreen displays FscmLogo', (tester) async {
    final fakeController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => fakeController),
        ],
        child: const MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(FscmLogo), findsOneWidget);
    expect(find.text('FSCM'), findsOneWidget);
  });

  testWidgets('LoginScreen displays FscmLogo and FSCM branding', (tester) async {
    final fakeController = _FakeAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => fakeController),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(FscmLogo), findsOneWidget);
    expect(find.text('FSCM'), findsOneWidget);
  });
}

