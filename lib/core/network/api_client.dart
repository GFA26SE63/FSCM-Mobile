import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';

/// Default transport = real HTTP. `main.dart` overrides it with `MockApi`
/// when `Env.useMock` is true.
final apiTransportProvider = Provider<ApiTransport>((ref) {
  return DioTransport(baseUrl: Env.apiBaseUrl);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final client = ApiClient(
    transport: ref.watch(apiTransportProvider),
    tokenReader: () => tokens.accessToken,
    refreshTokenReader: () => tokens.refreshToken,
    onTokenRefreshed: (sessionJson) => tokens.save(sessionJson),
  );
  ref.onDispose(client.dispose);
  return client;
});

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
            );

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
          throw const ApiException.network();
        default:
          final res = e.response;
          if (res != null) {
            return ApiResponse(statusCode: res.statusCode ?? 0, data: res.data);
          }
          throw ApiException.network(e.message);
      }
    }
  }
}

/// Thin JSON client: adds the bearer token, attempts a single token refresh on
/// 401 (`POST /api/v1/auth/refresh`), maps ProblemDetails to [ApiException],
/// broadcasts unrecoverable 401s (logout) and 403s (Forbidden/Scope Denied).
class ApiClient {
  ApiClient({
    required ApiTransport transport,
    required String? Function() tokenReader,
    String? Function()? refreshTokenReader,
    Future<void> Function(Map<String, dynamic> session)? onTokenRefreshed,
  })  : _transport = transport,
        _tokenReader = tokenReader,
        _refreshTokenReader = refreshTokenReader,
        _onTokenRefreshed = onTokenRefreshed;

  final ApiTransport _transport;
  final String? Function() _tokenReader;
  final String? Function()? _refreshTokenReader;
  final Future<void> Function(Map<String, dynamic> session)? _onTokenRefreshed;
  final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();
  final StreamController<ApiException> _forbidden =
      StreamController<ApiException>.broadcast();
  Future<bool>? _refreshInFlight;

  /// Fires when a call returns 401 and token refresh is unavailable or fails.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  /// Fires when a call returns 403 (Insufficient permissions or scope).
  Stream<ApiException> get onForbidden => _forbidden.stream;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path,
          {Object? body, Map<String, dynamic>? query}) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  static bool _isAuthEndpoint(String path) =>
      path == Endpoints.authLogin ||
      path == Endpoints.authRefresh ||
      path == Endpoints.authLogout ||
      path == Endpoints.authEntraExchange;

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final cleanQuery = query == null
        ? null
        : (Map<String, dynamic>.of(query)..removeWhere((_, v) => v == null));

    ApiResponse response = await _transport.send(
      ApiRequest(
        method: method,
        path: path,
        query: cleanQuery,
        body: body,
        headers: _buildHeaders(),
      ),
    );

    if (response.statusCode == 401 && !_isAuthEndpoint(path)) {
      final refreshed = await _tryRefreshOnce();
      if (refreshed) {
        response = await _transport.send(
          ApiRequest(
            method: method,
            path: path,
            query: cleanQuery,
            body: body,
            headers: _buildHeaders(),
          ),
        );
      }
    }

    if (response.isSuccess) return response.data;

    final error = ApiException.fromProblem(response.statusCode, response.data);
    if (error.kind == ApiErrorKind.unauthorized &&
        !_isAuthEndpoint(path) &&
        !_unauthorized.isClosed) {
      _unauthorized.add(null);
    }
    if (error.kind == ApiErrorKind.forbidden && !_forbidden.isClosed) {
      _forbidden.add(error);
    }
    throw error;
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = _tokenReader();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<bool> _tryRefreshOnce() {
    final inflight = _refreshInFlight;
    if (inflight != null) return inflight;
    final future = _performRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _refreshTokenReader?.call();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _transport.send(
        ApiRequest(
          method: 'POST',
          path: Endpoints.authRefresh,
          body: <String, dynamic>{'refreshToken': refreshToken},
          headers: const <String, String>{'Accept': 'application/json'},
        ),
      );
      if (!response.isSuccess || response.data is! Map) return false;
      final map = (response.data as Map).cast<String, dynamic>();
      final accessToken = map['accessToken']?.toString() ?? '';
      if (accessToken.isEmpty) return false;
      final onRefreshed = _onTokenRefreshed;
      if (onRefreshed != null) {
        await onRefreshed(map);
      }
      return true;
    } on Object {
      return false;
    }
  }

  void dispose() {
    unawaited(_unauthorized.close());
    unawaited(_forbidden.close());
  }
}
