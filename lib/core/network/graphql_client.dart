import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';

final graphQlClientProvider = Provider<GraphQlClient>(
    (ref) => GraphQlClient(ref.watch(apiClientProvider)));

/// Thin GraphQL layer over [ApiClient]: bearer token, timeouts, HTTP-level
/// errors and the single-flight 401 refresh all stay in [ApiClient]. This only
/// adds what GraphQL needs: a request envelope, and errors that arrive inside
/// a 200 response mapped onto [ApiException].
///
/// Read-only on purpose: business WRITE operations stay on REST.
class GraphQlClient {
  GraphQlClient(this._api, {String Function()? endpoint})
      : _endpoint = endpoint ?? (() => Env.effectiveGraphQlEndpoint);

  final ApiClient _api;
  final String Function() _endpoint;

  /// Codes emitted by HotChocolate.Authorization (used by the Web portal's
  /// client). The Backend source does not define them itself, so they are
  /// unverified against a live server.
  static const String notAuthenticatedCode = 'AUTH_NOT_AUTHENTICATED';
  static const String notAuthorizedCode = 'AUTH_NOT_AUTHORIZED';

  /// True when a failed GraphQL read may be retried once through the matching
  /// REST endpoint: a generic or schema error (the Backend hides domain errors
  /// behind a generic message). Network, authentication and authorization
  /// failures never fall back.
  static bool canFallBackToRest(ApiException error) =>
      !error.isNetwork &&
      error.kind != ApiErrorKind.unauthorized &&
      error.kind != ApiErrorKind.forbidden;

  /// Returns the `data` object. Any `errors` entry fails the whole call, even
  /// when partial data came with it.
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic>? variables,
    String? operationName,
  }) =>
      _execute(document, variables, operationName, isRetry: false);

  Future<Map<String, dynamic>> _execute(
    String document,
    Map<String, dynamic>? variables,
    String? operationName, {
    required bool isRetry,
  }) async {
    final sentToken = _api.accessToken;
    // HTTP and network failures throw ApiException from here.
    final response = await _api.post(
      _endpoint(),
      body: <String, dynamic>{
        'query': document,
        if (variables != null) 'variables': variables,
        if (operationName != null) 'operationName': operationName,
      },
    );
    if (response is! Map) throw _invalid('Phản hồi GraphQL không hợp lệ.');

    final errors = response['errors'];
    if (errors is List && errors.isNotEmpty) {
      final error = errorFrom(errors);
      if (error.kind == ApiErrorKind.unauthorized) {
        if (!isRetry && await _sessionRecovered(sentToken)) {
          return _execute(document, variables, operationName, isRetry: true);
        }
        _api.reportUnauthorized();
      }
      throw error;
    }

    final data = response['data'];
    if (data is! Map) throw _invalid('GraphQL không trả dữ liệu.');
    return Map<String, dynamic>.from(data);
  }

  /// True when a retry is worth one attempt: another request already
  /// refreshed the token, or the refresh succeeds now (single-flight inside
  /// [ApiClient]). Network errors during refresh propagate; the session stays.
  Future<bool> _sessionRecovered(String? sentToken) async {
    final current = _api.accessToken;
    if (current != null && current.isNotEmpty && current != sentToken) {
      return true;
    }
    return _api.tryRefreshToken();
  }

  /// Maps GraphQL `errors` to the existing exception contract, keeping the
  /// message, `extensions.code` and the raw entries.
  static ApiException errorFrom(List<Object?> errors) {
    final entries = errors
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final first = entries.isEmpty ? <String, dynamic>{} : entries.first;
    final extensions = first['extensions'];
    final code = extensions is Map ? extensions['code']?.toString() : null;

    final kind = switch (code) {
      notAuthenticatedCode => ApiErrorKind.unauthorized,
      notAuthorizedCode => ApiErrorKind.forbidden,
      _ => ApiErrorKind.validation,
    };
    final status = switch (kind) {
      ApiErrorKind.unauthorized => 401,
      ApiErrorKind.forbidden => 403,
      _ => 400,
    };
    final messages = entries
        .map((e) => e['message']?.toString() ?? '')
        .where((m) => m.isNotEmpty)
        .toList();
    return ApiException(
      kind: kind,
      statusCode: status,
      code: code,
      message: messages.isEmpty ? 'Không tải được dữ liệu.' : messages.first,
      details: messages.length > 1 ? messages.join('\n') : null,
      problemDetails: <String, dynamic>{'graphQlErrors': entries},
    );
  }

  static ApiException _invalid(String message) => ApiException(
      kind: ApiErrorKind.server, statusCode: 502, message: message);
}
