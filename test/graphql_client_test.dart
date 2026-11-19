import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';

const _endpoint = 'http://host/graphql';

class _Store extends TokenStore {
  _Store(this._session);
  Map<String, dynamic>? _session;

  @override
  String? get accessToken => _session?['accessToken'] as String?;
  @override
  String? get refreshToken => _session?['refreshToken'] as String?;
  @override
  Map<String, dynamic>? get cachedSession => _session;
  @override
  Future<void> save(Map<String, dynamic> session) async => _session = session;
}

class _Transport implements ApiTransport {
  _Transport(this.onGraphQl);

  final ApiResponse Function(ApiRequest request, int call) onGraphQl;
  final List<ApiRequest> graphQlRequests = <ApiRequest>[];
  int refreshCalls = 0;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == '/auth/refresh') {
      refreshCalls++;
      return const ApiResponse(statusCode: 200, data: <String, dynamic>{
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      });
    }
    graphQlRequests.add(request);
    return onGraphQl(request, graphQlRequests.length);
  }
}

ApiResponse _errors(String code, {Map<String, dynamic>? data}) => ApiResponse(
      statusCode: 200,
      data: <String, dynamic>{
        'data': data,
        'errors': <Map<String, dynamic>>[
          <String, dynamic>{
            'message': 'boom $code',
            'extensions': <String, dynamic>{'code': code},
          },
        ],
      },
    );

({GraphQlClient gql, ApiClient api, _Transport transport, _Store store}) _build(
    ApiResponse Function(ApiRequest, int) onGraphQl,
    {String? refreshToken = 'old-refresh'}) {
  final store = _Store(<String, dynamic>{
    'accessToken': 'old-access',
    'refreshToken': refreshToken,
    'user': <String, dynamic>{
      'id': 'user-1',
      'fullName': 'Test',
      'email': 't@fscm.vn',
      'role': 'Sales',
    },
  });
  final transport = _Transport(onGraphQl);
  final api = ApiClient(
    transport: transport,
    tokenReader: () => store.accessToken,
    tokenStore: store,
  );
  addTearDown(api.dispose);
  return (
    gql: GraphQlClient(api, endpoint: () => _endpoint),
    api: api,
    transport: transport,
    store: store,
  );
}

void main() {
  test('sends query, variables and bearer token to the configured endpoint',
      () async {
    final t = _build(
        (_, __) => const ApiResponse(statusCode: 200, data: <String, dynamic>{
              'data': <String, dynamic>{'ok': 1}
            }));

    final data = await t.gql.query('query Q { ok }',
        operationName: 'Q', variables: <String, dynamic>{'a': 1});

    expect(data['ok'], 1);
    final request = t.transport.graphQlRequests.single;
    expect(request.path, _endpoint);
    expect(request.headers['Authorization'], 'Bearer old-access');
    final body = request.body! as Map<String, dynamic>;
    expect(body['query'], 'query Q { ok }');
    expect(body['operationName'], 'Q');
    expect(body['variables'], <String, dynamic>{'a': 1});
  });

  test('GraphQL errors in a 200 response fail the call, partial data ignored',
      () async {
    final t = _build((_, __) =>
        _errors('SOME_CODE', data: <String, dynamic>{'partial': true}));

    await expectLater(
      t.gql.query('{ x }'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'SOME_CODE')
          .having((e) => e.message, 'message', 'boom SOME_CODE')
          .having((e) => e.kind, 'kind', ApiErrorKind.validation)
          .having((e) => e.problemDetails?['graphQlErrors'], 'raw errors',
              isA<List<dynamic>>())),
    );
    expect(t.transport.refreshCalls, 0);
  });

  test('missing data without errors is an error', () async {
    final t = _build((_, __) => const ApiResponse(
        statusCode: 200, data: <String, dynamic>{'data': null}));
    await expectLater(t.gql.query('{ x }'), throwsA(isA<ApiException>()));
  });

  test('HTTP errors stay HTTP errors, not GraphQL errors', () async {
    final t = _build((_, __) => const ApiResponse(
        statusCode: 500, data: <String, dynamic>{'title': 'Server'}));
    await expectLater(
      t.gql.query('{ x }'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.server)
          .having((e) => e.statusCode, 'status', 500)),
    );
  });

  test('network and timeout failures propagate unchanged', () async {
    for (final failure in <ApiException>[
      const ApiException.network(),
      const ApiException.timeout(),
    ]) {
      final api = ApiClient(
        transport: _ThrowingTransport(failure),
        tokenReader: () => 'token',
      );
      addTearDown(api.dispose);
      await expectLater(
        GraphQlClient(api, endpoint: () => _endpoint).query('{ x }'),
        throwsA(same(failure)),
      );
    }
  });

  test('AUTH_NOT_AUTHENTICATED refreshes once, retries once and succeeds',
      () async {
    final t = _build((request, call) => call == 1
        ? _errors(GraphQlClient.notAuthenticatedCode)
        : const ApiResponse(statusCode: 200, data: <String, dynamic>{
            'data': <String, dynamic>{'ok': 1}
          }));

    expect((await t.gql.query('{ ok }'))['ok'], 1);
    expect(t.transport.refreshCalls, 1);
    expect(t.transport.graphQlRequests, hasLength(2));
    expect(t.transport.graphQlRequests.last.headers['Authorization'],
        'Bearer new-access');
  });

  test('persistent AUTH_NOT_AUTHENTICATED stops after one retry and logs out',
      () async {
    final t = _build((_, __) => _errors(GraphQlClient.notAuthenticatedCode));
    var loggedOut = 0;
    final sub = t.api.onUnauthorized.listen((_) => loggedOut++);
    addTearDown(sub.cancel);

    await expectLater(
      t.gql.query('{ x }'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
          .having((e) => e.code, 'code', GraphQlClient.notAuthenticatedCode)),
    );
    await pumpEventQueue();

    expect(t.transport.graphQlRequests, hasLength(2));
    expect(t.transport.refreshCalls, 1);
    expect(loggedOut, 1);
  });

  test('no refresh token: unauthenticated logs out without refresh', () async {
    final t = _build((_, __) => _errors(GraphQlClient.notAuthenticatedCode),
        refreshToken: null);
    var loggedOut = 0;
    final sub = t.api.onUnauthorized.listen((_) => loggedOut++);
    addTearDown(sub.cancel);

    await expectLater(t.gql.query('{ x }'), throwsA(isA<ApiException>()));
    await pumpEventQueue();

    expect(t.transport.refreshCalls, 0);
    expect(t.transport.graphQlRequests, hasLength(1));
    expect(loggedOut, 1);
  });

  test('AUTH_NOT_AUTHORIZED is forbidden: no refresh, no logout', () async {
    final t = _build((_, __) => _errors(GraphQlClient.notAuthorizedCode));
    var loggedOut = 0;
    final sub = t.api.onUnauthorized.listen((_) => loggedOut++);
    addTearDown(sub.cancel);

    await expectLater(
      t.gql.query('{ x }'),
      throwsA(isA<ApiException>()
          .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)),
    );
    await pumpEventQueue();

    expect(t.transport.refreshCalls, 0);
    expect(loggedOut, 0);
  });

  test('request logging redacts GraphQL query, variables and tokens', () async {
    final lines = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    addTearDown(() => debugPrint = original);

    final dio = Dio(BaseOptions(baseUrl: 'http://host/api/v1'))
      ..httpClientAdapter = _JsonAdapter();
    final api = ApiClient(
      transport: DioTransport(baseUrl: 'http://host/api/v1', dio: dio),
      tokenReader: () => 'SECRET-TOKEN',
    );
    addTearDown(api.dispose);

    await GraphQlClient(api, endpoint: () => _endpoint).query(
      'query Q { retailerSecretField }',
      operationName: 'Q',
      variables: <String, dynamic>{'taxCode': 'TAX-123'},
    );

    final log = lines.join('\n');
    expect(log, contains('GraphQL: Q'));
    expect(log, isNot(contains('retailerSecretField')));
    expect(log, isNot(contains('TAX-123')));
    expect(log, isNot(contains('SECRET-TOKEN')));
  });
}

class _ThrowingTransport implements ApiTransport {
  _ThrowingTransport(this.error);
  final ApiException error;

  @override
  Future<ApiResponse> send(ApiRequest request) async => throw error;
}

class _JsonAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'ok': 1}
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
