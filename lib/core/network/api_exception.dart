/// Error mapping for the REST API. The backend answers errors with RFC 7807
/// ProblemDetails (`type`, `title`, `status`, `detail`, `errors`, optional
/// `code`); network failures are mapped to [ApiErrorKind.network].
enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.title,
    this.code,
    this.errors = const <String, List<String>>{},
  });

  const ApiException.network([String? message])
      : this(
          kind: ApiErrorKind.network,
          message: message ??
              'Không có kết nối mạng. Kiểm tra wifi / 4G rồi thử lại.',
        );

  const ApiException.timeout()
      : this(
          kind: ApiErrorKind.timeout,
          message: 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.',
        );

  const ApiException.notFoundLocal()
      : this(
          kind: ApiErrorKind.notFound,
          message: 'Không tìm thấy đơn hàng trên máy.',
        );

  factory ApiException.fromProblem(int status, Object? body) {
    String? title;
    String? detail;
    String? code;
    final errors = <String, List<String>>{};
    if (body is Map) {
      title = body['title']?.toString();
      detail = body['detail']?.toString();
      code = body['code']?.toString();
      final rawErrors = body['errors'];
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value.map((e) => e.toString()).toList();
          } else if (value != null) {
            errors[key.toString()] = <String>[value.toString()];
          }
        });
      }
    } else if (body is String && body.isNotEmpty && body.length < 300) {
      detail = body;
    }

    final kind = _kindFor(status);
    final firstFieldError =
        errors.values.isNotEmpty && errors.values.first.isNotEmpty
            ? errors.values.first.first
            : null;
    final message = detail ?? firstFieldError ?? title ?? _defaultMessage(kind);
    return ApiException(
      kind: kind,
      message: message,
      statusCode: status,
      title: title,
      code: code,
      errors: errors,
    );
  }

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? title;
  final String? code;
  final Map<String, List<String>> errors;

  bool get isNetwork =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  /// Worth retrying automatically (offline queue backoff).
  bool get isRetryable => isNetwork || kind == ApiErrorKind.server;

  static ApiErrorKind _kindFor(int status) {
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 404) return ApiErrorKind.notFound;
    if (status == 409) return ApiErrorKind.conflict;
    if (status == 400 || status == 422) return ApiErrorKind.validation;
    if (status >= 500) return ApiErrorKind.server;
    return ApiErrorKind.unknown;
  }

  static String _defaultMessage(ApiErrorKind kind) {
    switch (kind) {
      case ApiErrorKind.unauthorized:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case ApiErrorKind.forbidden:
        return 'Không đủ quyền/phạm vi truy cập.';
      case ApiErrorKind.notFound:
        return 'Không tìm thấy dữ liệu.';
      case ApiErrorKind.conflict:
        return 'Dữ liệu đã thay đổi, vui lòng tải lại.';
      case ApiErrorKind.validation:
        return 'Dữ liệu không hợp lệ.';
      case ApiErrorKind.server:
        return 'Hệ thống đang bận, vui lòng thử lại sau.';
      case ApiErrorKind.network:
        return 'Không có kết nối mạng.';
      case ApiErrorKind.timeout:
        return 'Máy chủ phản hồi quá lâu.';
      case ApiErrorKind.unknown:
        return 'Đã có lỗi xảy ra.';
    }
  }

  /// Human message for any error thrown inside the app.
  static String describe(Object error) {
    if (error is ApiException) return error.message;
    return 'Đã có lỗi xảy ra: $error';
  }

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}
