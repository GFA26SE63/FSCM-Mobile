import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/core/storage/token_store.dart';
import 'package:fscm_mobile/data/remote/auth_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

class _MemoryTokens extends TokenStore {
  _MemoryTokens(this.value);
  Map<String, dynamic> value;

  @override
  Future<Map<String, dynamic>?> load() async => value;

  @override
  Future<void> save(Map<String, dynamic> session) async {
    value = session;
  }
}

class _UnusedTransport implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    throw StateError('Unexpected request: ${request.path}');
  }
}

class _ProfileApi extends AuthApi {
  _ProfileApi(super.client, this.user);
  final AppUser user;
  int meCalls = 0;

  @override
  Future<AppUser> me() async {
    meCalls++;
    return user;
  }
}

void main() {
  for (final role in ['Retailer', 'Sales', 'WarehouseKeeper']) {
    test('restored $role session loads and persists current profile labels',
        () async {
      final cachedUser = <String, dynamic>{
        'id': 'user',
        'role': role,
        'fullName': 'Cached name',
      };
      final tokens = _MemoryTokens(<String, dynamic>{
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': cachedUser,
      });
      final client = ApiClient(
        transport: _UnusedTransport(),
        tokenReader: () => 'access',
      );
      addTearDown(client.dispose);
      final api = _ProfileApi(
          client,
          AppUser.fromJson(<String, dynamic>{
            ...cachedUser,
            'fullName': 'Current name',
            'scope': <String, dynamic>{
              'retailerIds': ['r'],
              'salesGroupIds': ['g'],
              'warehouseIds': ['w'],
            },
            'scopeLabels': <String, dynamic>{
              'retailers': [
                {'id': 'r', 'code': '10004127', 'name': 'Điểm bán'}
              ],
              'salesGroups': [
                {'id': 'g', 'code': 'G1', 'name': 'Nhóm Sales'}
              ],
              'warehouses': [
                {'id': 'w', 'code': 'WH1', 'name': 'Kho'}
              ],
            },
          }));
      final container = ProviderContainer(overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(client),
        authApiProvider.overrideWithValue(api),
      ]);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.notifier).restore();
      await Future<void>.delayed(Duration.zero);
      expect(api.meCalls, 1);
      final user = container.read(currentUserProvider)!;
      expect(user.fullName, 'Current name');
      final persisted = Session.fromJson(tokens.value);
      expect(persisted.accessToken, 'access');
      expect(persisted.refreshToken, 'refresh');
      if (role == 'Retailer') {
        expect(persisted.user.retailerCode, '10004127');
        expect(persisted.user.retailerName, 'Điểm bán');
      } else if (role == 'Sales') {
        expect(persisted.user.salesGroupLabels.single.code, 'G1');
      } else {
        expect(persisted.user.warehouseLabels.single.code, 'WH1');
      }
    });
  }

  test('periodic /me with an unchanged profile does not republish the user',
      () async {
    final cachedUser = <String, dynamic>{
      'id': 'user',
      'role': 'Retailer',
      'fullName': 'Same name',
    };
    final tokens = _MemoryTokens(<String, dynamic>{
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'user': cachedUser,
    });
    final client =
        ApiClient(transport: _UnusedTransport(), tokenReader: () => 'access');
    addTearDown(client.dispose);
    final api =
        _ProfileApi(client, AppUser.fromJson(<String, dynamic>{...cachedUser}));
    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(client),
      authApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await controller.restore();
    await Future<void>.delayed(Duration.zero);
    final before = container.read(currentUserProvider);
    var emissions = 0;
    container.listen(currentUserProvider, (_, __) => emissions++);

    await controller.verifySessionOnResume();

    // A new user instance would rebuild every provider watching it (screens reload).
    expect(api.meCalls, 2);
    expect(emissions, 0);
    expect(identical(container.read(currentUserProvider), before), isTrue);
  });

  test('token refresh with the same profile keeps the same user object',
      () async {
    final cachedUser = <String, dynamic>{
      'id': 'user',
      'role': 'Retailer',
      'fullName': 'Same name',
    };
    final tokens = _MemoryTokens(<String, dynamic>{
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'user': cachedUser,
    });
    final client = _RefreshingClient();
    addTearDown(client.dispose);
    final api =
        _ProfileApi(client, AppUser.fromJson(<String, dynamic>{...cachedUser}));
    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(client),
      authApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).restore();
    await Future<void>.delayed(Duration.zero);
    final before = container.read(currentUserProvider);
    var emissions = 0;
    container.listen(currentUserProvider, (_, __) => emissions++);

    client.refreshed.add(Session.fromJson(<String, dynamic>{
      'accessToken': 'access-2',
      'refreshToken': 'refresh-2',
      'user': cachedUser,
    }));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authControllerProvider).session!.accessToken,
        'access-2');
    expect(emissions, 0);
    expect(identical(container.read(currentUserProvider), before), isTrue);
  });
}

class _RefreshingClient extends ApiClient {
  _RefreshingClient()
      : super(transport: _UnusedTransport(), tokenReader: () => 'access');
  final refreshed = StreamController<Session>.broadcast();

  @override
  Stream<Session> get onSessionRefreshed => refreshed.stream;
}
