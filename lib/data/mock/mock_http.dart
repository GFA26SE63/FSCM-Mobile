import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Parsed request handed to the mock handlers.
class MockRequest {
  MockRequest({
    required this.method,
    required this.segments,
    required this.query,
    required this.body,
    required this.user,
  });

  final String method;

  /// Path split by `/`, e.g. `['orders', 'DH-001030', 'cancel']`.
  final List<String> segments;
  final Map<String, dynamic> query;
  final Map<String, dynamic> body;
  final MockUser? user;

  bool get isGet => method == 'GET';
  bool get isPost => method == 'POST';

  /// True when the path equals [pattern] where `*` matches any one segment.
  bool matches(String verb, String pattern) {
    if (method != verb) return false;
    final parts = pattern.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.length != segments.length) return false;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != '*' && parts[i] != segments[i]) return false;
    }
    return true;
  }

  String queryStr(String key) => asStr(query[key]);
}

/// Response builders (JSON bodies are plain maps/lists).
class MockReply {
  MockReply._();

  static ApiResponse ok(Object? data) =>
      ApiResponse(statusCode: 200, data: data);

  static ApiResponse created(Object? data) =>
      ApiResponse(statusCode: 201, data: data);

  static ApiResponse noContent() => const ApiResponse(statusCode: 204);

  /// RFC 7807 style problem.
  static ApiResponse problem(int status, String detail,
          {String? title, String? code}) =>
      ApiResponse(
        statusCode: status,
        data: <String, dynamic>{
          'type': 'about:blank',
          'title': title ?? 'Lỗi',
          'status': status,
          'detail': detail,
          if (code != null) 'code': code,
        },
      );

  static ApiResponse notFound(String what) =>
      problem(404, 'Không tìm thấy $what.', title: 'Not Found');

  static ApiResponse forbidden(String detail) =>
      problem(403, detail, title: 'Forbidden');

  static ApiResponse conflict(String detail, {String? code}) =>
      problem(409, detail, title: 'Conflict', code: code);

  static ApiResponse invalid(String detail) =>
      problem(400, detail, title: 'Validation');

  static ApiResponse page(List<Map<String, dynamic>> items) =>
      ok(<String, dynamic>{
        'items': items,
        'total': items.length,
        'page': 1,
        'size': items.length,
      });
}

/// A group of mock endpoints. Returns null when the request is not theirs.
abstract class MockHandler {
  MockHandler(this.store);

  final MockStore store;

  ApiResponse? handle(MockRequest r);
}
