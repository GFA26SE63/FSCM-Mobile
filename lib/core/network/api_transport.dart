/// Transport abstraction under [ApiClient].
///
/// `DioTransport` (api_client.dart) talks HTTP to the ASP.NET Core API.
class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.path,
    this.query,
    this.body,
    this.headers = const <String, String>{},
  });

  final String method;

  /// Path relative to `Env.apiBaseUrl`, e.g. `/orders/sync`.
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;
  final Map<String, String> headers;

  @override
  String toString() => '$method $path';
}

class ApiResponse {
  const ApiResponse({required this.statusCode, this.data});

  final int statusCode;
  final Object? data;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract class ApiTransport {
  /// Must throw `ApiException` for network-level failures and return an
  /// [ApiResponse] (any status) when the server answered.
  Future<ApiResponse> send(ApiRequest request);
}
