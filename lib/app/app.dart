import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Global key to display toasts/snackbars across the entire app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
int _manualStatusVersion = 0;

void showRootStatus(String message, {bool error = false, bool manual = false}) {
  if (manual) _manualStatusVersion++;
  final messenger = rootScaffoldMessengerKey.currentState;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor:
            error ? const Color(0xFFB42318) : const Color(0xFF1B1F1D),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4)));
}

/// Root widget: Vietnamese `MaterialApp.router` with the teal theme,
/// automatic session/scope verification on resume (§3.3), and 403 banner (§2.3).
class FscmApp extends ConsumerStatefulWidget {
  const FscmApp({super.key});

  @override
  ConsumerState<FscmApp> createState() => _FscmAppState();
}

class _FscmAppState extends ConsumerState<FscmApp> with WidgetsBindingObserver {
  StreamSubscription<ApiStatusFeedback>? _statusFeedbackSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _statusFeedbackSub =
        ref.read(apiClientProvider).onStatusFeedback.listen((feedback) {
      final version = _manualStatusVersion;
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (_manualStatusVersion == version)
          showRootStatus(
              feedback.isError
                  ? feedback.error!.message
                  : 'Thao tác thành công.',
              error: feedback.isError);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_statusFeedbackSub?.cancel());
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
