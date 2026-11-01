import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Global key to display toasts/snackbars across the entire app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Root widget: Vietnamese `MaterialApp.router` with the teal theme,
/// automatic session/scope verification on resume (§3.3), and 403 banner (§2.3).
class FscmApp extends ConsumerStatefulWidget {
  const FscmApp({super.key});

  @override
  ConsumerState<FscmApp> createState() => _FscmAppState();
}

class _FscmAppState extends ConsumerState<FscmApp> with WidgetsBindingObserver {
  StreamSubscription<ApiException>? _forbiddenSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to 403 Forbidden errors to display "Không đủ quyền/phạm vi" (§2.3)
    _forbiddenSub = ref.read(apiClientProvider).onForbidden.listen((error) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFB42318),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_forbiddenSub?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // SPRINT_1_FRONTEND_MOBILE_API_GUIDE.md §3.3:
      // "Khi app resume hoặc nhận 401/403, phải tái kiểm tra phiên/scope."
      unawaited(
        ref.read(authControllerProvider.notifier).verifySessionOnResume(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'FSCM',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: buildAppTheme(),
      routerConfig: router,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const <Locale>[Locale('vi', 'VN'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
