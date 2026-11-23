import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

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

void showRootStatus(String message,
    {bool error = false, double bottomClearance = 0}) {
  rootFeedback.show(message, error: error, bottomClearance: bottomClearance);
}

void showRootUndoStatus(String message,
    {required VoidCallback onUndo, double bottomClearance = 0}) {
  rootFeedback.showUndo(message,
      onUndo: onUndo, bottomClearance: bottomClearance);
}

void hideRootUndoStatus() => rootFeedback.hideUndo();

/// Margin of a floating SnackBar. [bottomClearance] lifts it above a bar that
/// lives inside the page body (e.g. the order checkout bar), which the
/// Scaffold cannot see, so feedback never covers that bar's action.
EdgeInsets _snackMargin(double bottomClearance) => EdgeInsets.fromLTRB(
    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg + bottomClearance);

class _QueuedFeedback {
  const _QueuedFeedback(this.message, this.error, [this.bottomClearance = 0]);

  final String message;
  final bool error;
  final double bottomClearance;
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
  bool _activeIsUndo = false;

  /// Shows only one feedback channel at a time.
  ///
  /// Success messages are intentionally never queued: the updated screen is
  /// already the acknowledgement, and a stale success must not cover the next
  /// CTA. Errors preempt a success and are queued in arrival order so an
  /// important failure is never silently discarded.
  void show(String message, {bool error = false, double bottomClearance = 0}) {
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
      _pendingErrors.add(_QueuedFeedback(normalized, true, bottomClearance));
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
    _present(_QueuedFeedback(normalized, error, bottomClearance));
  }

  void showUndo(String message,
      {required VoidCallback onUndo, double bottomClearance = 0}) {
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    final id = ++_activeId;
    _activeFingerprint = 'info:$normalized';
    _activeIsError = false;
    _activeIsUndo = true;
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(normalized),
        action: SnackBarAction(label: 'Hoàn tác', onPressed: onUndo),
        behavior: SnackBarBehavior.floating,
        margin: _snackMargin(bottomClearance),
        duration: _duration,
        // Flutter keeps a SnackBar that has an action on screen until it is
        // dismissed (and ignores `duration`) unless persist is false.
        persist: false,
      ),
    );
    unawaited(controller.closed.then((_) {
      // A newer message may already be active: only the latest one resets.
      if (id != _activeId) return;
      _activeFingerprint = null;
      _activeIsError = false;
      _activeIsUndo = false;
    }));
  }

  /// Hides a pending undo message (e.g. when its screen is left, where "Hoàn
  /// tác" would no longer make sense). Errors and other messages are untouched.
  void hideUndo() {
    if (!_activeIsUndo) return;
    _messengerKey.currentState?.hideCurrentSnackBar();
  }

  void _present(_QueuedFeedback feedback) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;

    final id = ++_activeId;
    _activeFingerprint =
        '${feedback.error ? 'error' : 'info'}:${feedback.message}';
    _activeIsError = feedback.error;
    _activeIsUndo = false;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(feedback.message),
        backgroundColor: feedback.error ? AppColors.danger : AppColors.text,
        behavior: SnackBarBehavior.floating,
        margin: _snackMargin(feedback.bottomClearance),
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
