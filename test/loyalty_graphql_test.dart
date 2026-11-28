import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/remote/loyalty_api.dart';

import 'fixtures/loyalty_fixture.dart';

class _Transport implements ApiTransport {
  _Transport({this.onGraphQl, this.onRest});

  ApiResponse Function(String query)? onGraphQl;
  ApiResponse Function(ApiRequest request)? onRest;
  final List<ApiRequest> graphQl = <ApiRequest>[];
  final List<ApiRequest> rest = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == Env.effectiveGraphQlEndpoint) {
      graphQl.add(request);
      final handler = onGraphQl;
      if (handler == null) throw StateError('unexpected GraphQL call');
      return handler((request.body! as Map)['query'] as String);
    }
    rest.add(request);
    final handler = onRest;
    if (handler == null) throw StateError('unexpected REST call');
    return handler(request);
  }

  String get query => (graphQl.last.body! as Map)['query'] as String;
  String get restCalls => rest.map((r) => '${r.method} ${r.path}').join(',');
}

ApiResponse _program(Object? nodes) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{
          'loyaltyPrograms': <String, dynamic>{'nodes': nodes},
        },
      },
    });

ApiResponse _errors(String message, [String? code]) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': null,
      'errors': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': message,
          if (code != null) 'extensions': <String, dynamic>{'code': code},
        },
      ],
    });

LoyaltyApi _api(_Transport t) {
  final client = ApiClient(transport: t, tokenReader: () => 'token');
  addTearDown(client.dispose);
  return LoyaltyApi(client);
}

Map<String, dynamic> _reward() => <String, dynamic>{
      'id': 'gift-1',
      'code': 'QUA-001',
      'name': 'Quà A',
      'loyaltyProgramId': 'program-1',
      'requiredPoints': 100,
      'availableQuantity': 5,
      'isActive': true,
      'description': 'Mô tả',
      // The Backend turns a stored blob key into a signed read URL.
      'imageUrl': 'https://blob.example/signed?sig=abc',
    };

void main() {
  test(
      'new card supplies all eligible programs without reading a single reference program',
      () async {
    final t = _Transport(
      onGraphQl: (_) =>
          throw StateError('eligible program details are already on the card'),
      onRest: (_) => ApiResponse(statusCode: 200, data: {
        ...loyaltyCardFixture(),
        'eligiblePrograms': [
          {...loyaltyProgramFixture(), 'isActive': true},
          {
            ...loyaltyProgramFixture(),
            'id': 'program-2',
            'code': 'LP-002',
            'isActive': true
          },
        ],
      }),
    );
    final account = await _api(t).account();
    expect(account.programs, hasLength(2));
    expect(t.graphQl, isEmpty);
    expect(t.restCalls, 'GET /loyalty/cards/me');
  });
  group('Loyalty program (read by id)', () {
    test('card is REST, the program on it is read through GraphQL', () async {
      final t = _Transport(
        onGraphQl: (_) => _program([loyaltyProgramFixture()]),
        onRest: (_) => ApiResponse(statusCode: 200, data: loyaltyCardFixture()),
      );

      final account = await _api(t).account();

      expect(t.restCalls, 'GET /loyalty/cards/me');
      expect(t.graphQl, hasLength(1));
      expect((t.graphQl.single.body! as Map)['variables'], {'id': 'program-1'});
      expect(
          (t.graphQl.single.body! as Map)['operationName'], 'LoyaltyProgram');
      // Backend-computed numbers come from the REST card, untouched.
      expect(account.balance, 500);
      expect(account.pending, 100);
      expect(account.held, 50);
      expect(account.expired, 20);
      expect(account.ledger, hasLength(1));
      // The exact (inactive) program and its decimal rate survive.
      expect(account.program!.isActive, isFalse);
      expect(account.program!.amountPerPoint, 12345.67);
      expect(account.program!.code, isNotEmpty);
    });

    test('query selects only the program fields, nothing about other retailers',
        () async {
      final t = _Transport(
        onGraphQl: (_) => _program([loyaltyProgramFixture()]),
        onRest: (_) => ApiResponse(statusCode: 200, data: loyaltyCardFixture()),
      );
      await _api(t).account();
      expect(t.query,
          contains('loyaltyPrograms(first: 1, where: { id: { eq: \$id } })'));
      for (final other in <String>[
        'retailerLoyalties',
        'loyaltyTransactions',
        'rewardRedemptions',
        'retailerIds',
        'RetailerIds',
        'loyaltyRewards',
      ]) {
        expect(t.query, isNot(contains(other)), reason: other);
      }
    });

    test('no program on the card sends no program request', () async {
      final t = _Transport(
        onGraphQl: (_) => throw StateError('no program to read'),
        onRest: (_) => ApiResponse(
            statusCode: 200, data: loyaltyCardFixture(programId: null)),
      );
      final account = await _api(t).account();
      expect(account.program, isNull);
      expect(t.graphQl, isEmpty);
    });

    test('empty answer: REST decides (it reports "not found" precisely)',
        () async {
      final t = _Transport(
        onGraphQl: (_) => _program([]),
        onRest: (request) => ApiResponse(
            statusCode: 200,
            data: request.path == '/loyalty/cards/me'
                ? loyaltyCardFixture()
                : loyaltyProgramFixture()),
      );
      final account = await _api(t).account();
      expect(account.program!.amountPerPoint, 12345.67);
      expect(
          t.restCalls, 'GET /loyalty/cards/me,GET /loyalty/programs/program-1');
    });

    test('generic error falls back to REST; auth and network do not', () async {
      final generic = _Transport(
        onGraphQl: (_) => _errors('Unexpected Execution Error'),
        onRest: (request) => ApiResponse(
            statusCode: 200,
            data: request.path == '/loyalty/cards/me'
                ? loyaltyCardFixture()
                : loyaltyProgramFixture()),
      );
      expect((await _api(generic).account()).program, isNotNull);

      final denied = _Transport(
        onGraphQl: (_) => _errors('no', 'AUTH_NOT_AUTHENTICATED'),
        onRest: (_) => ApiResponse(statusCode: 200, data: loyaltyCardFixture()),
      );
      await expectLater(_api(denied).account(), throwsA(isA<ApiException>()));
      expect(denied.restCalls, 'GET /loyalty/cards/me'); // no program fallback

      final offline = _Transport(
        onGraphQl: (_) => throw const ApiException.network(),
        onRest: (_) => ApiResponse(statusCode: 200, data: loyaltyCardFixture()),
      );
      await expectLater(_api(offline).account(),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
      expect(offline.rest, hasLength(1));
    });

    test('a malformed program is an error and is not retried', () async {
      for (final bad in <Object?>[
        null,
        'x',
        <Object>['not a map']
      ]) {
        final t = _Transport(
          onGraphQl: (_) => _program(bad),
          onRest: (_) =>
              ApiResponse(statusCode: 200, data: loyaltyCardFixture()),
        );
        await expectLater(_api(t).account(), throwsA(isA<ApiException>()));
        expect(t.rest, hasLength(1)); // only the card
      }
      // A program without a usable rate is rejected by the model, not defaulted.
      final noRate = _Transport(
        onGraphQl: (_) =>
            _program([loyaltyProgramFixture()..remove('spendAmountPerPoint')]),
        onRest: (_) => ApiResponse(statusCode: 200, data: loyaltyCardFixture()),
      );
      await expectLater(_api(noRate).account(), throwsA(isA<ApiException>()));
    });
  });

  group('Kept on REST', () {
    test('rewards: REST list with program filter and the signed image URL',
        () async {
      final t = _Transport(
        onGraphQl: (_) => throw StateError('rewards stay REST'),
        onRest: (_) => ApiResponse(statusCode: 200, data: [_reward()]),
      );
      final gifts = await _api(t).gifts(programId: 'program-1');

      expect(gifts.single.imageUrl, 'https://blob.example/signed?sig=abc');
      expect(gifts.single.stock, 5);
      expect(gifts.single.points, 100);
      expect(t.restCalls, 'GET /loyalty/rewards');
      expect(t.rest.single.query, {'programId': 'program-1'});
      expect(t.graphQl, isEmpty);
    });

    test('redemption history (M.5) still reads through GraphQL', () async {
      final t = _Transport(
        onGraphQl: (_) => const ApiResponse(statusCode: 200, data: {
          'data': {
            'entities': {'redemptionReads': <Object>[]},
          },
        }),
      );
      expect(await _api(t).redemptions(), isEmpty);
      expect(t.query, contains('redemptionReads {'));
      expect(t.rest, isEmpty);
    });

    test('redeem: REST, same key and body, no GraphQL', () async {
      final t = _Transport(
        onGraphQl: (_) => throw StateError('writes never use GraphQL'),
        onRest: (_) => const ApiResponse(statusCode: 200, data: {
          'id': 'r-1',
          'rewardCode': 'QUA-001',
          'rewardName': 'Quà A',
          'redeemedPoints': 200,
          'status': 'Pending',
          'quantity': 2,
          'quantityIsEstimated': false,
          'clientRequestId': 'key-1',
          'createdAt': '2026-11-17T00:00:00Z',
        }),
      );
      await _api(t)
          .redeem(rewardId: 'gift-1', quantity: 2, operationKey: 'key-1');
      expect(t.restCalls, 'POST /loyalty/redemptions');
      expect(t.rest.single.headers['Idempotency-Key'], 'key-1');
      expect(t.rest.single.body, {'rewardId': 'gift-1', 'quantity': 2});
      expect(t.graphQl, isEmpty);
    });

    test('programs list is untouched (REST)', () async {
      final t = _Transport(
        onGraphQl: (_) => throw StateError('the list stays REST'),
        onRest: (_) =>
            ApiResponse(statusCode: 200, data: [loyaltyProgramFixture()]),
      );
      expect(await _api(t).programs(), hasLength(1));
      expect(t.restCalls, 'GET /loyalty/programs');
    });
  });
}
