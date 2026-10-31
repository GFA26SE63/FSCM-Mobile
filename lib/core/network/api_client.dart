import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';

/// HTTP transport used by the repositories.
final apiTransportProvider = Provider<ApiTransport>((ref) {
  return DioTransport(baseUrl: Env.apiBaseUrl);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final client = ApiClient(
    transport: ref.watch(apiTransportProvider),
    tokenReader: () => tokens.accessToken,
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

/// Thin JSON client: adds the bearer token, maps ProblemDetails to
/// [ApiException] and broadcasts 401s so the auth layer can log out.
class ApiClient {
  ApiClient(
      {required ApiTransport transport,
      required String? Function() tokenReader})
      : _transport = transport,
        _tokenReader = tokenReader;

  final ApiTransport _transport;
  final String? Function() _tokenReader;
  final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();
  final StreamController<ApiException> _forbidden =
      StreamController<ApiException>.broadcast();

  /// Fires when any call returns 401.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  /// Fires when a call returns 403 so the UI can refresh scope and explain it.
  Stream<ApiException> get onForbidden => _forbidden.stream;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path,
          {Object? body,
          Map<String, dynamic>? query,
          Map<String, String>? headers}) =>
      _send('POST', path, body: body, query: query, extraHeaders: headers);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = _tokenReader();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
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
          headers: headers),
    );
    if (response.isSuccess) return response.data;

    final error = ApiException.fromProblem(response.statusCode, response.data);
    if (error.kind == ApiErrorKind.unauthorized && !_unauthorized.isClosed) {
      _unauthorized.add(null);
    }
    if (error.kind == ApiErrorKind.forbidden && !_forbidden.isClosed) {
      _forbidden.add(error);
    }
    throw error;
  }

  void dispose() {
    unawaited(_unauthorized.close());
    unawaited(_forbidden.close());
  }
}
