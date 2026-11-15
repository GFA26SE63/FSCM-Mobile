import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

/// Shared presentation-level feedback channel.
///
/// Screens own the decision to show feedback. This controller only coordinates
/// the resulting root Snackbar so repeated taps and concurrent operations do
/// not hide important errors or build up a queue of stale success messages.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final RootFeedbackController rootFeedback = RootFeedbackController(
  messengerKey: rootScaffoldMessengerKey,
);

void showRootStatus(String message, {bool error = false}) {
  rootFeedback.show(message, error: error);
}

class _QueuedFeedback {
  const _QueuedFeedback(this.message, this.error);

  final String message;
  final bool error;
}

class RootFeedbackController {
  RootFeedbackController({
    required GlobalKey<ScaffoldMessengerState> messengerKey,
    DateTime Function()? clock,
  })  : _messengerKey = messengerKey,
        _clock = clock ?? DateTime.now;

  static const Duration _cooldown = Duration(seconds: 3);
  static const Duration _duration = Duration(seconds: 4);

  final GlobalKey<ScaffoldMessengerState> _messengerKey;
  final DateTime Function() _clock;
  final Map<String, DateTime> _recent = <String, DateTime>{};
  final Queue<_QueuedFeedback> _pendingErrors = Queue<_QueuedFeedback>();

  int _activeId = 0;
  String? _activeFingerprint;
  bool _activeIsError = false;

  /// Shows only one feedback channel at a time.
  ///
  /// Success messages are intentionally never queued: the updated screen is
  /// already the acknowledgement, and a stale success must not cover the next
  /// CTA. Errors preempt a success and are queued in arrival order so an
  /// important failure is never silently discarded.
  void show(String message, {bool error = false}) {
    final normalized = message.trim();
    if (normalized.isEmpty) return;

    final now = _clock();
    final fingerprint = '${error ? 'error' : 'info'}:$normalized';
    _recent.removeWhere((_, seenAt) => now.difference(seenAt) >= _cooldown);
    if (_recent.containsKey(fingerprint) ||
        _activeFingerprint == fingerprint ||
        _pendingErrors.any((item) =>
            '${item.error ? 'error' : 'info'}:${item.message}' ==
            fingerprint)) {
      return;
    }
    _recent[fingerprint] = now;

    if (error && _activeFingerprint != null && _activeIsError) {
      _pendingErrors.add(_QueuedFeedback(normalized, true));
      return;
    }

    if (!error && _activeFingerprint != null) {
      return;
    }

    if (error && _activeFingerprint != null) {
      _messengerKey.currentState?.hideCurrentSnackBar(
        reason: SnackBarClosedReason.hide,
      );
    }
    _present(_QueuedFeedback(normalized, error));
  }

  void _present(_QueuedFeedback feedback) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;

    final id = ++_activeId;
    _activeFingerprint =
        '${feedback.error ? 'error' : 'info'}:${feedback.message}';
    _activeIsError = feedback.error;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(feedback.message),
        backgroundColor:
            feedback.error ? const Color(0xFFB42318) : const Color(0xFF1B1F1D),
        behavior: SnackBarBehavior.floating,
        duration: _duration,
      ),
    );
    unawaited(controller.closed.then((_) {
      if (id != _activeId) return;
      _activeFingerprint = null;
      _activeIsError = false;
      if (_pendingErrors.isNotEmpty) {
        _present(_pendingErrors.removeFirst());
      }
    }));
  }
}

/// Root widget: Vietnamese `MaterialApp.router` with the teal theme,
/// automatic session/scope verification on resume (§3.3), and 403 banner (§2.3).
class FscmApp extends ConsumerStatefulWidget {
  const FscmApp({super.key});

  @override
  ConsumerState<FscmApp> createState() => _FscmAppState();
}

class _FscmAppState extends ConsumerState<FscmApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
