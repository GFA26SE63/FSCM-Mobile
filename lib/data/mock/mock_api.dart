import 'dart:async';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_auth_handler.dart';
import 'package:fscm_mobile/data/mock/mock_catalog_handler.dart';
import 'package:fscm_mobile/data/mock/mock_finance_handler.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_orders_handler.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/mock/mock_warehouse_handler.dart';

/// In-process replacement of the ASP.NET Core API (`Env.useMock`). It
/// answers the same REST paths and JSON shapes as the real backend, so
/// repositories, parsing and the offline sync behave identically.
class MockApi implements ApiTransport {
  MockApi({MockStore? store}) : store = store ?? MockStore() {
    _handlers = <MockHandler>[
      MockAuthHandler(this.store),
      MockCatalogHandler(this.store),
      MockOrdersHandler(this.store),
      MockWarehouseHandler(this.store),
      MockFinanceHandler(this.store),
    ];
  }

  final MockStore store;
  late final List<MockHandler> _handlers;

  /// Set to true to make every call fail like a dead network (tests).
  bool forceOffline = false;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: Env.mockLatencyMs));
    if (forceOffline) throw const ApiException.network();

    final path = request.path.split('?').first;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final token = _bearer(request.headers['Authorization']);
    final user = store.userByToken(token);

    final isPublic = segments.isNotEmpty && segments.first == 'auth';
    if (!isPublic && user == null) {
      return MockReply.problem(
          401, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          title: 'Unauthorized');
    }

    final body = request.body;
    final mockRequest = MockRequest(
      method: request.method.toUpperCase(),
      segments: segments,
      query: request.query ?? const <String, dynamic>{},
      body: body is Map
          ? body.cast<String, dynamic>()
          : const <String, dynamic>{},
      user: user,
      headers: request.headers,
    );
    for (final h in _handlers) {
      final res = h.handle(mockRequest);
      if (res != null) return res;
    }
    return MockReply.problem(
        404, 'Mock API chưa hỗ trợ ${request.method} $path.',
        title: 'Not Found');
  }

  String? _bearer(String? header) {
    if (header == null) return null;
    const prefix = 'Bearer ';
    return header.startsWith(prefix) ? header.substring(prefix.length) : null;
  }
}
