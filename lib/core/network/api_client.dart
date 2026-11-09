import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/dio_adapter.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';

/// HTTP transport used by the repositories.
final apiTransportProvider = Provider<ApiTransport>((ref) {
  return DioTransport(baseUrl: Env.effectiveApiBaseUrl);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final client = ApiClient(
    transport: ref.watch(apiTransportProvider),
    tokenReader: () => tokens.accessToken,
    tokenStore: tokens,
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Interceptor to stream network activity to the console (adb logcat / flutter logs / terminal).
class _HttpLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('--> ${options.method} ${options.uri}');
    if (kDebugMode && options.data != null) {
      final isAuth = options.uri.path.contains('/auth');
      if (isAuth) {
        debugPrint('    Data: [REDACTED AUTH DATA]');
      } else {
        debugPrint('    Data: ${options.data}');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
      Response<Object?> response, ResponseInterceptorHandler handler) {
    debugPrint(
        '<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final uri = err.requestOptions.uri;
    final detail = '${err.type.name}: ${err.error ?? err.message}';
    debugPrint('<-- ERROR ${err.requestOptions.method} $uri: $detail');
    super.onError(err, handler);
  }
}

/// HTTP transport based on dio. Never throws for HTTP error statuses (they
/// are mapped by [ApiClient]); throws [ApiException] for network problems.
class DioTransport implements ApiTransport {
  DioTransport({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: Env.connectTimeout,
                receiveTimeout: Env.receiveTimeout,
                sendTimeout: Env.receiveTimeout,
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
                validateStatus: (_) => true,
              ),
            ) {
    if (dio == null) {
      configureDevHttpAdapter(_dio);
    }
    _dio.interceptors.add(_HttpLoggingInterceptor());
  }

  final Dio _dio;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    try {
      final response = await _dio.request<Object?>(
        request.path,
        data: request.body,
        queryParameters: request.query,
        options: Options(method: request.method, headers: request.headers),
      );
      return ApiResponse(
          statusCode: response.statusCode ?? 0, data: response.data);
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw const ApiException.timeout();
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          throw const ApiException.network();
        default:
          final res = e.response;
          if (res != null) {
            return ApiResponse(statusCode: res.statusCode ?? 0, data: res.data);
          }
          throw const ApiException.network();
      }
    }
  }
}

/// Thin JSON client: adds the bearer token, maps ProblemDetails to
/// [ApiException], coordinates single-flight token refresh on 401s,
/// and broadcasts unrecoverable 401s so the auth layer can log out.
class ApiClient {
  ApiClient({
    required ApiTransport transport,
    required String? Function() tokenReader,
    TokenStore? tokenStore,
  })  : _transport = transport,
        _tokenReader = tokenReader,
        _tokenStore = tokenStore;

  final ApiTransport _transport;
  final String? Function() _tokenReader;
  final TokenStore? _tokenStore;
  final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();
  final StreamController<ApiException> _forbidden =
      StreamController<ApiException>.broadcast();
  final StreamController<Session> _sessionRefreshed =
      StreamController<Session>.broadcast();

  Future<bool>? _refreshFuture;

  static const Set<String> _unauthenticatedAuthPaths = <String>{
    Endpoints.authLogin,
    Endpoints.authGoogleExchange,
    Endpoints.authOtpRequest,
    Endpoints.authOtpVerify,
    Endpoints.authSetPassword,
    Endpoints.authLogout,
    Endpoints.authRefresh,
    '/auth/activate',
    '/auth/password-reset/request',
    '/auth/password-reset/confirm',
  };

  /// Fires when any call returns 401 and refresh cannot recover the session.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  /// Fires when a token refresh succeeds with a new session.
  Stream<Session> get onSessionRefreshed => _sessionRefreshed.stream;

  /// Fires when a call returns 403 so the UI can refresh scope and explain it.
  Stream<ApiException> get onForbidden => _forbidden.stream;

  /// Public programmatic token refresh (e.g. on app launch if session is expired).
  Future<bool> tryRefreshToken() => _tryRefreshToken();

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) =>
      _send('POST', path, body: body, query: query, extraHeaders: headers);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  bool _isRefreshEligible(String path) {
    final refreshToken = _tokenStore?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    if (_unauthenticatedAuthPaths.contains(path)) {
      return false;
    }
    return true;
  }

  Future<bool> _tryRefreshToken() {
    final active = _refreshFuture;
    if (active != null) {
      return active;
    }
    final future = _executeRefresh();
    _refreshFuture = future;
    return future.whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<bool> _executeRefresh() async {
    final store = _tokenStore;
    if (store == null) return false;

    final refreshToken = store.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final initialRefreshToken = refreshToken;

    try {
      final response = await _transport.send(
        ApiRequest(
          method: 'POST',
          path: Endpoints.authRefresh,
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: <String, dynamic>{'refreshToken': refreshToken},
        ),
      );

      if (response.isSuccess) {
        // Guard against race condition: user logged out or switched account during refresh
        if (store.refreshToken != initialRefreshToken) {
          return false;
        }

        final data = response.data;
        if (data is! Map) return false;
        final map = data.cast<String, dynamic>();

        final newAccessToken = map['accessToken']?.toString();
        if (newAccessToken == null || newAccessToken.isEmpty) {
          return false;
        }

        final cached = store.cachedSession;
        final existingSession =
            cached != null ? Session.fromJson(cached) : null;

        final newRefreshToken = map['refreshToken']?.toString();
        final newExpiresAt = DateTime.tryParse(
          map['expiresAt']?.toString() ??
              map['accessTokenExpiresAt']?.toString() ??
              '',
        );
        final newRefreshTokenExpiresAt = DateTime.tryParse(
          map['refreshTokenExpiresAt']?.toString() ?? '',
        );

        final userMap = map['user'] as Map?;
        final user = (userMap != null && userMap.isNotEmpty)
            ? AppUser.fromJson(userMap.cast<String, dynamic>())
            : existingSession?.user ??
                AppUser(
                  id: '',
                  fullName: '',
                  phone: '',
                  role: UserRole.fromCode(null),
                );

        final updatedSession = Session(
          accessToken: newAccessToken,
          refreshToken: (newRefreshToken != null && newRefreshToken.isNotEmpty)
              ? newRefreshToken
              : refreshToken,
          expiresAt: newExpiresAt ?? existingSession?.expiresAt,
          refreshTokenExpiresAt: newRefreshTokenExpiresAt ??
              existingSession?.refreshTokenExpiresAt,
          user: user,
        );

        await store.save(updatedSession.toJson());

        if (!_sessionRefreshed.isClosed) {
          _sessionRefreshed.add(updatedSession);
        }
        return true;
      }

      // If refresh endpoint returns 400, 401, or 403, the refresh token is invalid/expired
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        return false;
      }

      // 5xx Server error
      final error =
          ApiException.fromProblem(response.statusCode, response.data);
      throw error;
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout) {
        rethrow;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? extraHeaders,
    bool isRetry = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final initialToken = _tokenReader();
    if (initialToken != null && initialToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $initialToken';
    }
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final cleanQuery = query == null
        ? null
        : (Map<String, dynamic>.of(query)..removeWhere((_, v) => v == null));

    final response = await _transport.send(
      ApiRequest(
        method: method,
        path: path,
        query: cleanQuery,
        body: body,
        headers: headers,
      ),
    );
    if (response.isSuccess) return response.data;

    final error = ApiException.fromProblem(response.statusCode, response.data);

    if (error.kind == ApiErrorKind.unauthorized) {
      if (!isRetry && _isRefreshEligible(path)) {
        // Check if another concurrent request already refreshed the token
        final currentToken = _tokenReader();
        if (currentToken != null &&
            currentToken.isNotEmpty &&
            currentToken != initialToken) {
          return _send(
            method,
            path,
            body: body,
            query: query,
            extraHeaders: extraHeaders,
            isRetry: true,
          );
        }

        var refreshed = false;
        try {
          refreshed = await _tryRefreshToken();
        } on ApiException catch (e) {
          if (e.kind == ApiErrorKind.network ||
              e.kind == ApiErrorKind.timeout) {
            rethrow;
          }
        }

        // The retry handles its own unauthorized event.
        // Its error must propagate without being caught by the refresh block.
        if (refreshed) {
          return await _send(
            method,
            path,
            body: body,
            query: query,
            extraHeaders: extraHeaders,
            isRetry: true,
          );
        }
      }

      if (!_unauthorized.isClosed) {
        _unauthorized.add(null);
      }
    }

    if (error.kind == ApiErrorKind.forbidden && !_forbidden.isClosed) {
      _forbidden.add(error);
    }
    throw error;
  }

  void dispose() {
    unawaited(_unauthorized.close());
    unawaited(_forbidden.close());
    unawaited(_sessionRefreshed.close());
  }
}
