import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
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

/// Role convenience providers for UI authorization
final isSalesProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.role == UserRole.sales,
);

final isWarehouseKeeperProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.role == UserRole.warehouseKeeper,
);

final isRetailerProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.role == UserRole.retailer,
);

/// Login / logout + session restore + RBAC session verification per
/// `SPRINT_1_FRONTEND_MOBILE_API_GUIDE.md` (§2.3, §3.2, §3.3, §5.1).
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.unknown()) {
    _unauthorizedSub = _ref.read(apiClientProvider).onUnauthorized.listen((_) {
      if (state.isAuthenticated) {
        unawaited(logout(callServer: false));
      }
    });

    _forbiddenSub = _ref.read(apiClientProvider).onForbidden.listen((_) {
      if (state.isAuthenticated) {
        // §3.3: Re-verify session and scope on 403
        unawaited(verifySessionOnResume());
      }
    });
  }

  final Ref _ref;
  StreamSubscription<void>? _unauthorizedSub;
  StreamSubscription<ApiException>? _forbiddenSub;

  TokenStore get _tokens => _ref.read(tokenStoreProvider);
  AuthApi get _authApi => _ref.read(authApiProvider);

  void clearError() {
    if (state.error == null) return;
    state = AuthState(status: state.status, session: state.session);
  }

  String _unsupportedRoleMessage(AppUser user, {String? identifier}) {
    if (user.role == UserRole.unsupported) {
      return 'Không có quyền truy cập FSCM Mobile. Vai trò tài khoản chưa được ứng dụng hỗ trợ.';
    }
    final account = user.email.isNotEmpty ? user.email : identifier;
    final accountText = account == null || account.isEmpty ? '' : ' $account';
    return 'Không có quyền truy cập FSCM Mobile. Tài khoản$accountText có vai trò ${user.role.label} và chỉ sử dụng trên Portal.';
  }

  /// Rejects Portal-only and unknown roles from every authentication entry
  /// point. The backend issues refresh tokens to every valid FSCM role, so a
  /// rejected mobile session is revoked as well as removed locally.
  Future<bool> _rejectUnsupportedSession(
    Session session, {
    String? identifier,
  }) async {
    if (session.user.role.hasMobileShell) return false;

    final refreshToken = session.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authApi.logout(refreshToken: refreshToken);
      } catch (_) {
        // Local rejection must still complete when the server is unavailable.
      }
    }
    await _tokens.clear();
    try {
      await _ref.read(appDatabaseProvider).clearCache();
    } catch (_) {
      // A cache failure must not leave an unsupported user authenticated.
    }
    state = AuthState(
      status: AuthStatus.unauthenticated,
      error: _unsupportedRoleMessage(
        session.user,
        identifier: identifier,
      ),
    );
    return true;
  }

  /// Called once from the splash screen (`POST /api/v1/auth/refresh` +
  /// `GET /api/v1/auth/me`, with offline fallback when local token is valid).
  Future<void> restore() async {
    final json = await _tokens.load();
    if (json == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    Session session = Session.fromJson(json);

    // Try refreshing session if refreshToken is present.
    final refreshToken = session.refreshToken;
    if (refreshToken != null &&
        refreshToken.isNotEmpty &&
        !session.isRefreshExpired) {
      try {
        final refreshed = await _authApi.refresh(refreshToken);
        session = refreshed.copyWith(
          user: session.user.mergeProfile(refreshed.user),
        );
        if (await _rejectUnsupportedSession(session)) return;
        await _tokens.save(session.toJson());
      } on ApiException catch (e) {
        if (e.kind == ApiErrorKind.unauthorized ||
            e.kind == ApiErrorKind.forbidden ||
            session.isExpired) {
          await _tokens.clear();
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
        // Network/timeout while accessToken is still valid: allow offline restore.
      }
    } else if (session.isExpired) {
      await _tokens.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Verify user status, role and scope via GET /api/v1/auth/me.
    try {
      final meUser = await _authApi.me();
      session = session.copyWith(user: session.user.mergeProfile(meUser));
      if (await _rejectUnsupportedSession(session)) return;
      await _tokens.save(session.toJson());
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized ||
          e.kind == ApiErrorKind.forbidden) {
        await _tokens.clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      // Offline fallback uses cached session user.
    }

    if (!session.user.isActive) {
      await _tokens.clear();
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Tài khoản đã bị vô hiệu hóa. Vui lòng liên hệ Admin.',
      );
      return;
    }

    if (await _rejectUnsupportedSession(session)) return;

    state = AuthState(status: AuthStatus.authenticated, session: session);
    unawaited(_registerDevice());
  }

  /// Re-verifies user active status, role and scope on app resume or 403
  /// (§3.3: "Khi app resume hoặc nhận 401/403, phải tái kiểm tra phiên/scope").
  Future<void> verifySessionOnResume() async {
    if (!state.isAuthenticated) return;
    try {
      final freshUser = await _authApi.me();

      // Check if user account was deactivated by Admin
      if (!freshUser.isActive) {
        await logout(callServer: false);
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Tài khoản đã bị vô hiệu hóa bởi Quản trị viên.',
        );
        return;
      }

      // Update session with fresh role and scope
      final currentSession = state.session;
      if (currentSession != null) {
        final updatedSession = currentSession.copyWith(
          user: currentSession.user.mergeProfile(freshUser),
        );
        if (await _rejectUnsupportedSession(updatedSession)) return;
        await _tokens.save(updatedSession.toJson());
        state = AuthState(
          status: AuthStatus.authenticated,
          session: updatedSession,
        );
      }
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.unauthorized ||
          e.kind == ApiErrorKind.forbidden) {
        await logout(callServer: false);
        state = AuthState(
          status: AuthStatus.unauthenticated,
          error: e.message,
        );
      }
      // Offline/timeout on resume keeps current session
    }
  }

  /// Signs in via `POST /api/v1/auth/login` using email (or phone for Customer tab)
  /// and password, then verifies role & scope.
  Future<bool> login(
    String identifier,
    String password, {
    String? phone,
  }) async {
    clearError();
    try {
      final cleanId = identifier.trim();
      final cleanPhone =
          (phone ?? (!cleanId.contains('@') ? cleanId : '')).replaceAll(
        RegExp(r'\s+'),
        '',
      );
      Session session = await _authApi.login(
        email: cleanId,
        password: password,
        phone: cleanPhone.isNotEmpty ? cleanPhone : null,
      );

      if (!session.user.isActive) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Tài khoản đã bị vô hiệu hóa. Vui lòng liên hệ Admin.',
        );
        return false;
      }

      if (await _rejectUnsupportedSession(session, identifier: cleanId)) {
        return false;
      }

      await _tokens.save(session.toJson());

      // Fetch /api/v1/auth/me to ensure latest role, active status & scope.
      try {
        final freshUser = await _authApi.me();
        session = session.copyWith(user: session.user.mergeProfile(freshUser));
        if (await _rejectUnsupportedSession(session, identifier: cleanId)) {
          return false;
        }
        await _tokens.save(session.toJson());
      } catch (e) {
        // Keep login response user if /auth/me is temporarily unreachable or throws.
        debugPrint('Notice: /auth/me profile fetch skipped: $e');
      }

      state = AuthState(status: AuthStatus.authenticated, session: session);
      unawaited(_registerDevice());
      return true;
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      return false;
    } catch (e, st) {
      debugPrint('Unexpected error in login: $e\n$st');
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Lỗi xác thực hoặc xử lý dữ liệu: $e',
      );
      return false;
    }
  }

  /// Completes authentication from an already-issued [Session] (e.g. after
  /// first-login OTP + password change or account activation).
  Future<bool> completeSession(Session session) async {
    clearError();
    if (await _rejectUnsupportedSession(session)) {
      return false;
    }
    await _tokens.save(session.toJson());
    state = AuthState(status: AuthStatus.authenticated, session: session);
    unawaited(_registerDevice());
    return true;
  }

  /// Logs the user out: calls `POST /api/v1/auth/logout` with refreshToken,
  /// clears access and refresh tokens from secure storage, and wipes cache.
  /// Every sub-step is guarded so logout is completely resilient.
  Future<void> logout({bool callServer = true}) async {
    final refreshToken = _tokens.refreshToken ?? state.session?.refreshToken;
    if (callServer && refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authApi.logout(refreshToken: refreshToken);
      } catch (_) {
        // Logging out must succeed even if server is offline or returns error.
      }
    }

    try {
      await _tokens.clear();
    } catch (_) {
      // Keystore clear issue must not prevent logout.
    }

    try {
      // Cached business data goes away; unsynced offline orders are kept.
      await _ref.read(appDatabaseProvider).clearCache();
    } catch (_) {
      // Local database clear failure should not prevent logout.
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _registerDevice() async {
    try {
      final identity = _ref.read(deviceIdentityProvider);
      String platform = 'android';
      if (!kIsWeb) {
        if (Platform.isIOS) {
          platform = 'ios';
        } else if (Platform.isAndroid) {
          platform = 'android';
        }
      } else {
        platform = 'web';
      }
      await _authApi.registerDevice(
        installId: identity.installId,
        platform: platform,
      );
    } on Object {
      // Push registration is best effort.
    }
  }

  @override
  void dispose() {
    unawaited(_unauthorizedSub?.cancel());
    unawaited(_forbiddenSub?.cancel());
    super.dispose();
  }
}
