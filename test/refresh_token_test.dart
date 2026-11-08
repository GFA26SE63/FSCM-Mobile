import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';

class MemoryTokenStore extends TokenStore {
  MemoryTokenStore([Map<String, dynamic>? initial]) : _memorySession = initial;

  Map<String, dynamic>? _memorySession;

  @override
  String? get accessToken => _memorySession?['accessToken'] as String?;

  @override
  String? get refreshToken => _memorySession?['refreshToken'] as String?;

  @override
  Map<String, dynamic>? get cachedSession => _memorySession;

  @override
  Future<Map<String, dynamic>?> load() async => _memorySession;

  @override
  Future<void> save(Map<String, dynamic> session) async {
    _memorySession = Map<String, dynamic>.from(session);
  }

  @override
  Future<void> clear() async {
    _memorySession = null;
  }
}

class FakeApiTransport implements ApiTransport {
  final List<ApiRequest> recordedRequests = <ApiRequest>[];
  final Map<String, FutureOr<ApiResponse> Function(ApiRequest)> handlers =
      <String, FutureOr<ApiResponse> Function(ApiRequest)>{};

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    recordedRequests.add(request);
    final key = '${request.method} ${request.path}';
    final handler = handlers[key] ?? handlers[request.path];
    if (handler != null) {
      return await handler(request);
    }
    return const ApiResponse(
        statusCode: 404, data: <String, dynamic>{'title': 'Not Found'});
  }
}

Map<String, dynamic> sampleSessionJson({
  String accessToken = 'initial-access-token',
  String refreshToken = 'initial-refresh-token',
  DateTime? expiresAt,
}) {
  return <String, dynamic>{
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt':
        (expiresAt ?? DateTime.now().add(const Duration(hours: 1)))
            .toIso8601String(),
    'refreshTokenExpiresAt':
        DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    'user': <String, dynamic>{
      'id': 'user-123',
      'fullName': 'Nguyễn Văn Test',
      'email': 'test@fscm.vn',
      'role': 'Sales',
    },
  };
}

void main() {
  late MemoryTokenStore tokenStore;
  late FakeApiTransport transport;
  late ApiClient client;

  setUp(() {
    tokenStore = MemoryTokenStore(sampleSessionJson());
    transport = FakeApiTransport();
    client = ApiClient(
      transport: transport,
      tokenReader: () => tokenStore.accessToken,
      tokenStore: tokenStore,
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('Automatic Refresh Token Flow', () {
    test('1. Access Token hợp lệ: request thành công, không gọi refresh',
        () async {
      transport.handlers['GET /orders'] = (req) {
        return const ApiResponse(
          statusCode: 200,
          data: <Map<String, dynamic>>[
            <String, dynamic>{'id': 'order-1'}
          ],
        );
      };

      final result = await client.get('/orders');

      expect(result, isNotNull);
      expect(transport.recordedRequests.length, 1);
      expect(transport.recordedRequests.first.path, '/orders');
      expect(transport.recordedRequests.first.headers['Authorization'],
          'Bearer initial-access-token');
      // Verify refresh was NEVER called
      expect(
          transport.recordedRequests
              .any((r) => r.path == Endpoints.authRefresh),
          isFalse);
    });

    test(
        '2. Access Token hết hạn, refresh thành công: retry thành công và giữ session',
        () async {
      var ordersCallCount = 0;
      transport.handlers['GET /orders'] = (req) {
        ordersCallCount++;
        if (ordersCallCount == 1) {
          // First attempt returns 401
          return const ApiResponse(
            statusCode: 401,
            data: <String, dynamic>{
              'type': 'https://httpstatuses.com/401',
              'title': 'Unauthorized',
              'status': 401,
            },
          );
        }
        // Second attempt with new token returns 200
        expect(req.headers['Authorization'], 'Bearer new-access-token');
        return const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{'orderId': 'OD-999', 'status': 'Confirmed'},
        );
      };

      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        expect(req.body,
            <String, dynamic>{'refreshToken': 'initial-refresh-token'});
        return const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'new-access-token',
            'accessTokenExpiresAt': '2026-12-01T00:00:00Z',
            'refreshToken': 'new-refresh-token',
            'refreshTokenExpiresAt': '2027-01-01T00:00:00Z',
          },
        );
      };

      var unauthorizedFired = false;
      client.onUnauthorized.listen((_) => unauthorizedFired = true);

      Session? refreshedSession;
      client.onSessionRefreshed.listen((s) => refreshedSession = s);

      final result = await client.get('/orders');

      expect(result, isNotNull);
      expect((result as Map)['orderId'], 'OD-999');
      expect(ordersCallCount, 2);
      expect(unauthorizedFired, isFalse);
      expect(refreshedSession, isNotNull);
      expect(refreshedSession!.accessToken, 'new-access-token');
      expect(refreshedSession!.refreshToken, 'new-refresh-token');
      expect(tokenStore.accessToken, 'new-access-token');
      expect(tokenStore.refreshToken, 'new-refresh-token');
    });

    test('3. Refresh Token hết hạn/không hợp lệ: kết thúc session đúng cách',
        () async {
      transport.handlers['GET /orders'] = (req) {
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };

      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        return const ApiResponse(
          statusCode: 401,
          data: <String, dynamic>{
            'type': 'https://httpstatuses.com/401',
            'title': 'Refresh token expired',
            'status': 401,
          },
        );
      };

      var unauthorizedCount = 0;
      client.onUnauthorized.listen((_) => unauthorizedCount++);

      expect(
        () => client.get('/orders'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
      );

      // Wait a microtask for streams to propagate
      await Future<void>.delayed(Duration.zero);
      expect(unauthorizedCount, 1);
    });

    test('4. Không có Refresh Token: không gọi refresh vô ích', () async {
      tokenStore = MemoryTokenStore(<String, dynamic>{
        'accessToken': 'some-access-token',
        'refreshToken': null, // No refresh token
      });
      client = ApiClient(
        transport: transport,
        tokenReader: () => tokenStore.accessToken,
        tokenStore: tokenStore,
      );

      transport.handlers['GET /orders'] = (req) {
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };

      var unauthorizedCount = 0;
      client.onUnauthorized.listen((_) => unauthorizedCount++);

      expect(
        () => client.get('/orders'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
      );

      await Future<void>.delayed(Duration.zero);
      expect(unauthorizedCount, 1);
      // Zero calls to refresh endpoint
      expect(
        transport.recordedRequests.any((r) => r.path == Endpoints.authRefresh),
        isFalse,
      );
    });

    test(
        '5. 3 request cùng 401 (Single-flight): chỉ đúng 1 refresh request được gửi',
        () async {
      var refreshCalls = 0;
      final refreshCompleter = Completer<ApiResponse>();

      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        refreshCalls++;
        return refreshCompleter.future;
      };

      var ordersCalls = 0;
      transport.handlers['GET /orders'] = (req) {
        ordersCalls++;
        if (ordersCalls == 1) {
          return const ApiResponse(
              statusCode: 401,
              data: <String, dynamic>{'title': 'Unauthorized'});
        }
        return const ApiResponse(
            statusCode: 200, data: <String, dynamic>{'name': 'Orders OK'});
      };

      var notifsCalls = 0;
      transport.handlers['GET /notifications'] = (req) {
        notifsCalls++;
        if (notifsCalls == 1) {
          return const ApiResponse(
              statusCode: 401,
              data: <String, dynamic>{'title': 'Unauthorized'});
        }
        return const ApiResponse(
            statusCode: 200, data: <String, dynamic>{'name': 'Notifs OK'});
      };

      var profileCalls = 0;
      transport.handlers['GET /auth/me'] = (req) {
        profileCalls++;
        if (profileCalls == 1) {
          return const ApiResponse(
              statusCode: 401,
              data: <String, dynamic>{'title': 'Unauthorized'});
        }
        return const ApiResponse(
            statusCode: 200, data: <String, dynamic>{'name': 'Profile OK'});
      };

      // Launch 3 concurrent requests
      final futureOrders = client.get('/orders');
      final futureNotifs = client.get('/notifications');
      final futureProfile = client.get('/auth/me');

      // Wait a tick for all 3 to receive 401 and queue on single-flight refresh
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(refreshCalls, 1);

      // Now complete the refresh
      refreshCompleter.complete(
        const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'new-single-flight-token',
            'refreshToken': 'new-single-flight-refresh',
          },
        ),
      );

      final results =
          await Future.wait([futureOrders, futureNotifs, futureProfile]);

      expect(results[0], <String, dynamic>{'name': 'Orders OK'});
      expect(results[1], <String, dynamic>{'name': 'Notifs OK'});
      expect(results[2], <String, dynamic>{'name': 'Profile OK'});

      // Exactly 1 refresh call over the wire!
      expect(refreshCalls, 1);
      expect(ordersCalls, 2);
      expect(notifsCalls, 2);
      expect(profileCalls, 2);
    });

    test('6. Refresh bị timeout/network error: không logout nhầm', () async {
      transport.handlers['GET /orders'] = (req) {
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };

      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        // Network failure during refresh
        throw const ApiException.network();
      };

      var unauthorizedCount = 0;
      client.onUnauthorized.listen((_) => unauthorizedCount++);

      // Should throw network exception, NOT unauthorized exception!
      expect(
        () => client.get('/orders'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.network)),
      );

      await Future<void>.delayed(Duration.zero);
      // unauthorized must NOT be fired on network error!
      expect(unauthorizedCount, 0);
      // Session in store remains intact
      expect(tokenStore.refreshToken, 'initial-refresh-token');
    });

    test('7. Refresh endpoint trả 401: không lặp vô hạn', () async {
      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };

      var unauthorizedCount = 0;
      client.onUnauthorized.listen((_) => unauthorizedCount++);

      // Calling refresh endpoint directly or when it returns 401
      expect(
        () => client.post(Endpoints.authRefresh,
            body: <String, dynamic>{'refreshToken': 'xyz'}),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
      );

      await Future<void>.delayed(Duration.zero);
      // Exactly 1 call was made to refresh, no recursive loop!
      expect(transport.recordedRequests.length, 1);
    });

    test('8. Request retry tiếp tục 401: không lặp vô hạn', () async {
      var ordersCalls = 0;
      transport.handlers['GET /orders'] = (req) {
        ordersCalls++;
        // Always returns 401
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };

      var refreshCalls = 0;
      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        refreshCalls++;
        return const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'another-token',
            'refreshToken': 'another-refresh',
          },
        );
      };

      var unauthorizedCount = 0;
      client.onUnauthorized.listen((_) => unauthorizedCount++);

      expect(
        () => client.get('/orders'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)),
      );

      await Future<void>.delayed(Duration.zero);
      // Orders was called exactly twice (1 initial + 1 retry)
      expect(ordersCalls, 2);
      // Refresh was called exactly once
      expect(refreshCalls, 1);
      // Finally emits unauthorized
      expect(unauthorizedCount, 1);
    });

    test('retry 403 preserves forbidden without emitting logout', () async {
      var calls = 0;
      transport.handlers['GET /orders'] = (_) => ApiResponse(
          statusCode: ++calls == 1 ? 401 : 403,
          data: const {'title': 'Access denied'});
      transport.handlers['POST ${Endpoints.authRefresh}'] =
          (_) => const ApiResponse(statusCode: 200, data: {
                'accessToken': 'new-access',
                'refreshToken': 'new-refresh',
              });
      var logouts = 0;
      var forbidden = 0;
      client.onUnauthorized.listen((_) => logouts++);
      client.onForbidden.listen((_) => forbidden++);
      await expectLater(
          client.get('/orders'),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(forbidden, 1);
      expect(logouts, 0);
    });

    test('9. Logout trong lúc refresh: không khôi phục session cũ', () async {
      final refreshCompleter = Completer<ApiResponse>();
      transport.handlers['GET /orders'] = (req) {
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };
      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        return refreshCompleter.future;
      };

      final futureCall = client.get('/orders');

      // While refresh is in flight, user logs out!
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tokenStore.clear();
      expect(tokenStore.refreshToken, isNull);

      // Now refresh completes with 200
      refreshCompleter.complete(
        const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'resurrected-token',
            'refreshToken': 'resurrected-refresh',
          },
        ),
      );

      try {
        await futureCall;
      } catch (_) {}

      // Verify token store did NOT save the resurrected session!
      expect(tokenStore.accessToken, isNull);
      expect(tokenStore.refreshToken, isNull);
    });

    test('10. Login tài khoản khác trong lúc refresh: không ghi đè token mới',
        () async {
      final refreshCompleter = Completer<ApiResponse>();
      transport.handlers['GET /orders'] = (req) {
        return const ApiResponse(
            statusCode: 401, data: <String, dynamic>{'title': 'Unauthorized'});
      };
      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        return refreshCompleter.future;
      };

      final futureCall = client.get('/orders');

      // While refresh for user A is in flight, user switches to account B
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tokenStore.save(sampleSessionJson(
        accessToken: 'userB-access',
        refreshToken: 'userB-refresh',
      ));

      // Now refresh completes for user A
      refreshCompleter.complete(
        const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'userA-new-access',
            'refreshToken': 'userA-new-refresh',
          },
        ),
      );

      try {
        await futureCall;
      } catch (_) {}

      // Token store must KEEP user B's tokens, not overwritten by user A!
      expect(tokenStore.accessToken, 'userB-access');
      expect(tokenStore.refreshToken, 'userB-refresh');
    });

    test('11. POST request bị 401: retry giữ nguyên payload và query params',
        () async {
      var postCalls = 0;
      transport.handlers['POST /orders'] = (req) {
        postCalls++;
        if (postCalls == 1) {
          return const ApiResponse(
              statusCode: 401,
              data: <String, dynamic>{'title': 'Unauthorized'});
        }
        // Verify payload and query are fully preserved on retry
        expect(req.body, <String, dynamic>{'sku': 'SKU-001', 'qty': 10});
        expect(req.query, <String, dynamic>{'draft': 'true'});
        expect(req.headers['Authorization'], 'Bearer refreshed-post-token');
        return const ApiResponse(
            statusCode: 201, data: <String, dynamic>{'orderId': 'CREATED-123'});
      };

      transport.handlers['POST ${Endpoints.authRefresh}'] = (req) {
        return const ApiResponse(
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'refreshed-post-token',
            'refreshToken': 'refreshed-post-refresh',
          },
        );
      };

      final result = await client.post(
        '/orders',
        body: <String, dynamic>{'sku': 'SKU-001', 'qty': 10},
        query: <String, dynamic>{'draft': 'true'},
      );

      expect((result as Map)['orderId'], 'CREATED-123');
      expect(postCalls, 2);
    });

    test('12. Session copyWith & isRefreshTokenExpired unit behavior', () {
      final s = Session.fromJson(sampleSessionJson(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ));

      expect(s.isExpired, isTrue);
      expect(s.isRefreshTokenExpired, isFalse);

      final updated = s.copyWith(accessToken: 'updated-token');
      expect(updated.accessToken, 'updated-token');
      expect(updated.refreshToken, s.refreshToken);
      expect(updated.user.id, s.user.id);
    });
  });
}
