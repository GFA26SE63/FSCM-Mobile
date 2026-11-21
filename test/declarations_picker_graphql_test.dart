import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/remote/retailers_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/retailer_repository.dart';

class _Transport implements ApiTransport {
  _Transport({this.onGraphQl, this.onRest});

  ApiResponse Function(String query, Map<String, dynamic> vars)? onGraphQl;
  ApiResponse Function(ApiRequest request)? onRest;
  final List<ApiRequest> graphQl = <ApiRequest>[];
  final List<ApiRequest> rest = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == Env.effectiveGraphQlEndpoint) {
      graphQl.add(request);
      final handler = onGraphQl;
      if (handler == null) throw StateError('unexpected GraphQL call');
      final body = request.body! as Map<String, dynamic>;
      return handler(body['query'] as String,
          (body['variables'] as Map<String, dynamic>?) ?? <String, dynamic>{});
    }
    rest.add(request);
    final handler = onRest;
    if (handler == null) throw StateError('unexpected REST call');
    return handler(request);
  }

  String get query => (graphQl.last.body! as Map)['query'] as String;
  String get restCalls => rest.map((r) => '${r.method} ${r.path}').join(',');
}

ApiResponse _entities(String field, Object? value) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{field: value},
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

RetailersApi _api(_Transport t) {
  final client = ApiClient(transport: t, tokenReader: () => 'token');
  addTearDown(client.dispose);
  return RetailersApi(client);
}

Map<String, dynamic> _declaration(int i,
        {String status = 'Draft', String updatedAt = '2026-11-10T00:00:00Z'}) =>
    <String, dynamic>{
      'id': 'id-$i',
      'code': 'KB-$i',
      'name': 'Cửa hàng $i',
      'contactName': 'Người liên hệ',
      'phone': '0900000000',
      'email': 'a@b.vn',
      'address': 'Địa chỉ',
      'latitude': 10.5,
      'longitude': 106.7,
      'providerPlaceId': 'place-1',
      'status': status,
      'retailerType': 'GroceryStore',
      'forecastRevenue': 1000000,
      'storeSizeSquareMeters': 20.5,
      'storeSizeCategory': 'S',
      'purchasingCapacity': 500000,
      'purchaseFrequencyPerMonth': 4,
      'creditTermDays': 0,
      'potentialClass': 'B',
      'assessmentNote': 'ghi chú',
      'salesGroupCode': 'G1',
      'reviewReason': '',
      'reviewedAt': null,
      'updatedAt': updatedAt,
      'mlorDeclarations': <Map<String, dynamic>>[
        <String, dynamic>{
          'scope': 'Sku',
          'productCategoryId': null,
          'productId': 'p1',
          'productSku': 'SKU-1',
          'productName': 'Sản phẩm',
          'categoryCode': null,
          'categoryName': null,
          'minimumLifeRatio': 0.6,
          'minimumLifeHours': 100,
        },
        <String, dynamic>{
          'scope': 'Category',
          'productCategoryId': 'c1',
          'productId': null,
          'productSku': null,
          'productName': null,
          'categoryCode': 'CAT',
          'categoryName': 'Ngành',
          'minimumLifeRatio': 0.5,
          'minimumLifeHours': null,
        },
      ],
    };

ApiResponse _page(List<Map<String, dynamic>> items,
        {required int page, required int total, int size = 100}) =>
    _entities('retailerProfiles', <String, dynamic>{
      'items': items,
      'page': page,
      'pageSize': size,
      'totalCount': total,
      'totalPages': (total / size).ceil(),
    });

const _sales =
    AppUser(id: 'u1', fullName: 'S', phone: '0', role: UserRole.sales);
const _retailer =
    AppUser(id: 'u2', fullName: 'R', phone: '0', role: UserRole.retailer);
const _keeper = AppUser(
    id: 'u3', fullName: 'K', phone: '0', role: UserRole.warehouseKeeper);

void main() {
  group('Retailer declarations', () {
    test('query is scoped to "mine" and carries page variables', () async {
      final t = _Transport(
          onGraphQl: (_, __) => _page([_declaration(1)], page: 1, total: 1));

      final rows = await _api(t).myDeclarations();

      expect(rows, hasLength(1));
      expect(t.rest, isEmpty);
      expect(t.query, contains('retailerProfiles(scope: "mine"'));
      final body = t.graphQl.single.body! as Map;
      expect(body['variables'], {'page': 1, 'pageSize': 100});
      expect(body['operationName'], 'MyDeclarations');
      // No user id or search is sent: the owner comes from the token.
      expect(t.query, isNot(contains('userId')));
    });

    test('the unscoped query, MLOR resolution and raw MLOR never appear',
        () async {
      final t = _Transport(
          onGraphQl: (_, __) => _page([_declaration(1)], page: 1, total: 1));
      await _api(t).myDeclarations();
      for (final forbidden in <String>[
        'retailerProfile(',
        'retailerMlorResolution',
        'retailerProductMlors',
        'AllocationRun',
        'allocationRun',
        'weightedScore',
        'defaultMlor',
      ]) {
        expect(t.query, isNot(contains(forbidden)), reason: forbidden);
      }
      // The only MLOR is the Sales user's own declaration inside the record.
      expect(t.query, contains('mlorDeclarations {'));
    });

    test('every displayed field is mapped; status and MLOR labels', () async {
      final t = _Transport(
          onGraphQl: (_, __) => _page(
              [_declaration(1, status: 'PendingApproval')],
              page: 1, total: 1));
      final d = (await _api(t).myDeclarations()).single;

      expect(d.id, 'id-1');
      expect(d.code, 'KB-1');
      expect(d.name, 'Cửa hàng 1');
      expect(d.contactName, 'Người liên hệ');
      expect(d.phone, '0900000000');
      expect(d.email, 'a@b.vn');
      expect(d.latitude, 10.5);
      expect(d.longitude, 106.7);
      expect(d.providerPlaceId, 'place-1');
      expect(d.status, DeclarationStatus.pendingApproval);
      expect(d.retailerType, RetailerTypeOption.groceryStore);
      expect(d.forecastRevenue, 1000000);
      expect(d.storeSizeCategory, 'S');
      expect(d.potentialClass, 'B');
      expect(d.salesGroupCode, 'G1');
      expect(d.mlorDeclarations, hasLength(2));
      expect(d.mlorDeclarations.first.label, 'SKU SKU-1 · Sản phẩm');
      expect(d.mlorDeclarations.first.minimumLifeHours, 100);
      expect(d.mlorDeclarations.last.label, 'Ngành hàng CAT · Ngành');
      expect(d.mlorDeclarations.last.minimumLifeRatio, 0.5);
    });

    test('every status code keeps its meaning', () async {
      for (final status in DeclarationStatus.values) {
        final t = _Transport(
            onGraphQl: (_, __) => _page([_declaration(1, status: status.code)],
                page: 1, total: 1));
        expect((await _api(t).myDeclarations()).single.status, status);
      }
    });

    test('newest update first, as before', () async {
      final t = _Transport(
          onGraphQl: (_, __) => _page([
                _declaration(1, updatedAt: '2026-11-01T00:00:00Z'),
                _declaration(2, updatedAt: '2026-11-05T00:00:00Z'),
              ], page: 1, total: 2));
      expect(
          (await _api(t).myDeclarations()).map((d) => d.id), ['id-2', 'id-1']);
    });

    test('more than 100: every page is read once, no duplicates', () async {
      final t = _Transport(onGraphQl: (_, vars) {
        final page = vars['page'] as int;
        final from = (page - 1) * 100;
        final count = page == 3 ? 50 : 100;
        return _page([for (var i = 0; i < count; i++) _declaration(from + i)],
            page: page, total: 250);
      });
      final rows = await _api(t).myDeclarations();
      expect(rows, hasLength(250));
      expect(rows.map((r) => r.id).toSet(), hasLength(250));
      expect(t.graphQl.map((r) => (r.body! as Map)['variables']['page']),
          [1, 2, 3]);
    });

    test('empty is empty; a malformed answer is an error', () async {
      final empty = _Transport(
          onGraphQl: (_, __) =>
              _page(<Map<String, dynamic>>[], page: 1, total: 0));
      expect(await _api(empty).myDeclarations(), isEmpty);

      final bad = _Transport(
          onGraphQl: (_, __) => _entities('retailerProfiles', null),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          _api(bad).myDeclarations(), throwsA(isA<ApiException>()));
    });

    test('generic error is re-read through REST (scope=mine); auth is not',
        () async {
      final t = _Transport(
        onGraphQl: (_, __) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(statusCode: 200, data: <String, dynamic>{
          'items': [_declaration(1)],
          'page': 1,
          'totalPages': 1,
        }),
      );
      expect(await _api(t).myDeclarations(), hasLength(1));
      expect(t.rest.single.path, '/retailers');
      expect(t.rest.single.query!['scope'], 'mine');

      final denied = _Transport(
          onGraphQl: (_, __) => _errors('no', 'AUTH_NOT_AUTHORIZED'),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          _api(denied).myDeclarations(),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)));

      final offline = _Transport(
          onGraphQl: (_, __) => throw const ApiException.network(),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(offline).myDeclarations(),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });

    test('only Sales asks: Retailer and Warehouse Keeper send nothing',
        () async {
      for (final user in <AppUser>[_retailer, _keeper]) {
        final t = _Transport(
            onGraphQl: (_, __) => _page([_declaration(1)], page: 1, total: 1));
        final client = ApiClient(transport: t, tokenReader: () => 'token');
        addTearDown(client.dispose);
        final container = ProviderContainer(overrides: [
          currentUserProvider.overrideWithValue(user),
          retailersApiProvider.overrideWithValue(RetailersApi(client)),
        ]);
        addTearDown(container.dispose);
        final sub = container.listen(declarationsProvider, (_, __) {});
        addTearDown(sub.close);
        await expectLater(container.read(declarationsProvider.future),
            throwsA(isA<ApiException>()));
        expect(t.graphQl, isEmpty);
        expect(t.rest, isEmpty);
      }

      final t = _Transport(
          onGraphQl: (_, __) => _page([_declaration(1)], page: 1, total: 1));
      final client = ApiClient(transport: t, tokenReader: () => 'token');
      addTearDown(client.dispose);
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_sales),
        retailersApiProvider.overrideWithValue(RetailersApi(client)),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(declarationsProvider, (_, __) {});
      addTearDown(sub.close);
      expect(await container.read(declarationsProvider.future), hasLength(1));
    });

    test('declare, update and submit stay REST', () async {
      final t = _Transport(
        onGraphQl: (_, __) => throw StateError('writes never use GraphQL'),
        onRest: (_) => ApiResponse(statusCode: 200, data: _declaration(1)),
      );
      final api = _api(t);
      const input = RetailerDeclarationInput(
        name: 'A',
        contactName: 'B',
        phone: '0900000000',
        email: 'a@b.vn',
        address: 'C',
        retailerType: RetailerTypeOption.groceryStore,
        forecastRevenue: 1,
        storeSizeSquareMeters: 10,
        purchasingCapacity: 1,
        purchaseFrequencyPerMonth: 1,
        assessmentNote: '',
        mlorDeclarations: <MlorDeclaration>[],
        submitForReview: false,
      );

      await api.declare(input, regionId: 'r', salesGroupId: 'g');
      await api.updateDeclaration('id-1', input);
      await api.submitForReview('id-1');

      expect(t.graphQl, isEmpty);
      expect(t.restCalls,
          'POST /retailers,PUT /retailers/id-1/declaration,POST /retailers/id-1/submit-review');
    });
  });

  group('Product and category picker', () {
    ApiResponse categories(List<Map<String, dynamic>> nodes, {String? next}) =>
        _entities('productCategories', <String, dynamic>{
          'nodes': nodes,
          'pageInfo': <String, dynamic>{
            'hasNextPage': next != null,
            'endCursor': next,
          },
        });

    Map<String, dynamic> category(int i, {bool active = true}) =>
        <String, dynamic>{
          'id': 'c$i',
          'code': 'CAT$i',
          'name': 'Ngành $i',
          'isActive': active,
        };

    test('categories: active only, code order, no MLOR fields', () async {
      final t = _Transport(
          onGraphQl: (_, __) => categories([category(1), category(2)]));

      final rows = await _api(t).mlorCategories();

      expect(rows.map((r) => r.code), ['CAT1', 'CAT2']);
      expect(rows.first.id, 'c1');
      expect(rows.first.name, 'Ngành 1');
      expect(rows.first.label, 'CAT1 · Ngành 1');
      expect(t.query, contains('where: { isActive: { eq: true } }'));
      expect(t.query, contains('order: [{ code: ASC }]'));
      expect(t.query, contains('first: 100'));
      for (final hidden in <String>['defaultMlor', 'DefaultMlor', 'mlor']) {
        expect(t.query, isNot(contains(hidden)));
      }
      expect(t.rest, isEmpty);
    });

    test('categories follow the cursor to the end', () async {
      final t = _Transport(onGraphQl: (_, vars) {
        return vars['after'] == null
            ? categories([category(1), category(2)], next: 'cursor-1')
            : categories([category(3)]);
      });
      final rows = await _api(t).mlorCategories();
      expect(rows.map((r) => r.code), ['CAT1', 'CAT2', 'CAT3']);
      expect(t.graphQl, hasLength(2));
      expect((t.graphQl.last.body! as Map)['variables'], {'after': 'cursor-1'});
    });

    test('a repeated page ends the cursor loop; inactive rows are dropped',
        () async {
      final t = _Transport(
          onGraphQl: (_, __) => categories(
              [category(1), category(2, active: false)],
              next: 'same'));
      final rows = await _api(t).mlorCategories();
      expect(rows.map((r) => r.code), ['CAT1']);
      expect(t.graphQl.length, lessThanOrEqualTo(2));
    });

    test('categories: empty, malformed, error fallback', () async {
      final empty = _Transport(onGraphQl: (_, __) => categories([]));
      expect(await _api(empty).mlorCategories(), isEmpty);

      final bad = _Transport(
          onGraphQl: (_, __) => _entities('productCategories', null),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          _api(bad).mlorCategories(), throwsA(isA<ApiException>()));

      final generic = _Transport(
        onGraphQl: (_, __) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(statusCode: 200, data: [category(1)]),
      );
      expect((await _api(generic).mlorCategories()).single.code, 'CAT1');
      expect(generic.restCalls, 'GET /categories');

      final denied = _Transport(
          onGraphQl: (_, __) => _errors('no', 'AUTH_NOT_AUTHENTICATED'),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          _api(denied).mlorCategories(), throwsA(isA<ApiException>()));
    });

    ApiResponse products(List<Map<String, dynamic>> nodes) =>
        _entities('products', <String, dynamic>{'nodes': nodes});

    Map<String, dynamic> product(int i, {String status = 'Published'}) =>
        <String, dynamic>{
          'id': 'p$i',
          'sku': 'SKU-$i',
          'name': 'Sản phẩm $i',
          'shelfLifeHours': 720,
          'status': status,
        };

    test('products: first 100 by SKU, inactive dropped, fields mapped',
        () async {
      final t = _Transport(
          onGraphQl: (_, __) => products([
                product(1),
                product(2, status: 'Inactive'),
                product(3, status: 'Draft'),
              ]));

      final rows = await _api(t).mlorProducts();

      expect(rows.map((r) => r.code), ['SKU-1', 'SKU-3']);
      expect(rows.first.id, 'p1');
      expect(rows.first.name, 'Sản phẩm 1');
      expect(rows.first.shelfLifeHours, 720);
      expect(rows.first.label, 'SKU-1 · Sản phẩm 1');
      expect(t.query, contains('products(first: 100, order: [{ sku: ASC }])'));
      expect(t.query, isNot(contains('where')));
      expect(t.rest, isEmpty);
    });

    test('products: with a search the case-insensitive REST search is used',
        () async {
      final t = _Transport(
        onGraphQl: (_, __) => throw StateError('search stays REST'),
        onRest: (_) => ApiResponse(statusCode: 200, data: <String, dynamic>{
          'items': [product(1)],
        }),
      );
      final rows = await _api(t).mlorProducts(search: 'sku');
      expect(rows.single.code, 'SKU-1');
      expect(t.rest.single.query!['search'], 'sku');
      expect(t.graphQl, isEmpty);
    });

    test('products: empty, malformed, error fallback', () async {
      final empty = _Transport(onGraphQl: (_, __) => products([]));
      expect(await _api(empty).mlorProducts(), isEmpty);

      final bad = _Transport(
          onGraphQl: (_, __) => _entities('products', null),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(bad).mlorProducts(), throwsA(isA<ApiException>()));

      final generic = _Transport(
        onGraphQl: (_, __) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(statusCode: 200, data: <String, dynamic>{
          'items': [product(1)],
        }),
      );
      expect((await _api(generic).mlorProducts()).single.code, 'SKU-1');
      expect(generic.rest.single.path, '/products');
      expect(generic.rest.single.query!['page'], 1);
      expect(generic.rest.single.query!['pageSize'], 100);

      final offline = _Transport(
          onGraphQl: (_, __) => throw const ApiException.timeout(),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(offline).mlorProducts(),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });
  });
}
