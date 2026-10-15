import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/remote/auth_api.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({required this.status, this.session, this.error});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  final AuthStatus status;
  final Session? session;

  /// Last login error (Vietnamese), shown on the login screen.
  final String? error;

  AppUser? get user => session?.user;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
    (ref) => AuthController(ref));

/// Signed-in user, or null.
final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);

/// Login / logout + session restore. The API client reads the bearer token
/// from [TokenStore]; a 401 anywhere logs the user out.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.unknown()) {
    _unauthorizedSub = _ref.read(apiClientProvider).onUnauthorized.listen((_) {
      if (state.isAuthenticated) {
        unawaited(logout(callServer: false));
      }
    });
  }

  final Ref _ref;
  StreamSubscription<void>? _unauthorizedSub;

  TokenStore get _tokens => _ref.read(tokenStoreProvider);

  /// Called once from the splash screen.
  Future<void> restore() async {
    final json = await _tokens.load();
    if (json == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final session = Session.fromJson(json);
    if (session.isExpired || !session.user.role.hasMobileShell) {
      await _tokens.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    state = AuthState(status: AuthStatus.authenticated, session: session);
    unawaited(_registerDevice());
  }

  Future<bool> login(String phone, String password) async {
    try {
      final session = await _ref
          .read(authApiProvider)
          .login(phone: phone.trim(), password: password);
      if (!session.user.role.hasMobileShell) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error:
              'Tài khoản này dùng Portal, không đăng nhập được trên app di động.',
        );
        return false;
      }
      await _tokens.save(session.toJson());
      state = AuthState(status: AuthStatus.authenticated, session: session);
      unawaited(_registerDevice());
      return true;
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      return false;
    }
  }

  Future<void> logout({bool callServer = true}) async {
    if (callServer) {
      try {
        await _ref.read(authApiProvider).logout();
      } on ApiException {
        // Logging out must work offline.
      }
    }
    await _tokens.clear();
    // Cached business data goes away; unsynced offline orders are kept.
    await _ref.read(appDatabaseProvider).clearCache();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _registerDevice() async {
    try {
      final identity = _ref.read(deviceIdentityProvider);
      await _ref.read(authApiProvider).registerDevice(
            installId: identity.installId,
            platform: Platform.isIOS ? 'ios' : 'android',
          );
    } on Object {
      // Push registration is best effort.
    }
  }

  @override
  void dispose() {
    unawaited(_unauthorizedSub?.cancel());
    super.dispose();
  }
}
