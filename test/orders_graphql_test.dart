import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/app_database.dart';
import 'package:fscm_mobile/data/local/daos/offline_order_dao.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const _orderId = '11111111-1111-4111-8111-111111111111';

class _Transport implements ApiTransport {
  _Transport(this.onGraphQl, {this.onRest});

  final ApiResponse Function(String query, Map<String, dynamic> variables)
      onGraphQl;
  final ApiResponse Function(ApiRequest request)? onRest;
  final List<ApiRequest> graphQl = <ApiRequest>[];
  final List<ApiRequest> rest = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == Env.effectiveGraphQlEndpoint) {
      graphQl.add(request);
      final body = request.body! as Map<String, dynamic>;
      return onGraphQl(body['query'] as String,
          (body['variables'] as Map<String, dynamic>?) ?? <String, dynamic>{});
    }
    rest.add(request);
    return onRest?.call(request) ??
        const ApiResponse(statusCode: 200, data: <String, dynamic>{});
  }

  String get restCalls => rest.map((r) => '${r.method} ${r.path}').join(',');
}

ApiResponse _orders(List<Map<String, dynamic>> items,
        {required int page, required int total, int pageSize = 20}) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{
          'orderReads': <String, dynamic>{
            'items': items,
            'page': page,
            'pageSize': pageSize,
            'totalCount': total,
          },
        },
      },
    });

Map<String, dynamic> _summary(int i, {String status = 'Quoted'}) =>
    <String, dynamic>{
      'id': 'id-$i',
      'orderCode': 'DH-$i',
      'retailerCode': 'RT1',
      'retailerName': 'Retailer',
      'status': status,
      'finalAmount': 1000,
      'lineCount': 2,
      'totalCartons': 3,
      'source': 'Online',
      'version': 1,
      'createdAt':
          DateTime.utc(2026, 11, 1).add(Duration(minutes: i)).toIso8601String(),
    };

Map<String, dynamic> _detailJson() => <String, dynamic>{
      'id': _orderId,
      'orderCode': 'DH-1',
      'retailerId': 'r1',
      'retailerCode': 'RT1',
      'retailerName': 'Retailer',
      'status': 'Quoted',
      'paymentMethod': 'Prepaid',
      'subtotalAmount': 1000,
      'discountAmount': 100,
      'finalAmount': 900,
      'creditTermDays': 0,
      'version': 3,
      'source': 'Online',
      'createdAt': '2026-11-01T00:00:00Z',
      'payment': <String, dynamic>{'method': 'Prepaid', 'status': 'Pending'},
      'history': <Map<String, dynamic>>[
        <String, dynamic>{
          'toStatus': 'Quoted',
          'reason': '',
          'changedAt': '2026-11-01T00:00:00Z',
        },
      ],
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{
          'sku': 'S1',
          'productName': 'P',
          'quantity': 10,
          'unitPrice': 100,
          'grossAmount': 1000,
          'discountAmount': 100,
          'discountPercent': 10,
          'discountSourceType': 'Campaign',
          'discountSourceCode': 'KM-1',
          'ordinaryPromotion': <String, dynamic>{
            'promotionId': 'x',
            'code': 'KM-1',
            'name': 'Khuyến mãi A',
            'discountAmount': 100,
          },
          'allocationFragments': <Map<String, dynamic>>[
            <String, dynamic>{
              'batchCode': 'B1',
              'quantity': 10,
              'batchExpirationDate': '2027-01-01',
              'warehouseCode': 'W1',
              'finalUnitPrice': 90,
              'netAmount': 900,
            },
          ],
          'allocations': <Object>[],
        },
      ],
    };

ApiResponse _detail() => ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'entities': <String, dynamic>{'orderRead': _detailJson()},
      },
    });

ApiResponse _error(String message, [String? code]) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': null,
      'errors': <Map<String, dynamic>>[
        <String, dynamic>{
          'message': message,
          if (code != null) 'extensions': <String, dynamic>{'code': code},
        },
      ],
    });

OrdersApi _api(_Transport t) {
  final client = ApiClient(transport: t, tokenReader: () => 'token');
  addTearDown(client.dispose);
  return OrdersApi(client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('list', () {
    test('reads a page through GraphQL with server-side search and paging',
        () async {
      final t = _Transport(
          (_, __) => _orders([_summary(1), _summary(2)], page: 1, total: 22));

      final page =
          await _api(t).listPage(page: 1, pageSize: 20, search: ' DH ');

      expect(page.items.map((o) => o.code), ['DH-1', 'DH-2']);
      expect(page.items.first.status, OrderStatus.quoted);
      expect(page.items.first.lineCount, 2);
      expect(page.totalCount, 22);
      expect(page.hasMore, isTrue); // 1 * 20 < 22
      final body = t.graphQl.single.body! as Map<String, dynamic>;
      expect(body['query'], contains('orderReads'));
      expect(body['variables'], <String, dynamic>{
        'status': null,
        'search': 'DH',
        'page': 1,
        'pageSize': 20,
      });
      expect(t.rest, isEmpty);
    });

    test('blank search is not sent; no client ordering is requested', () async {
      final t = _Transport((_, __) => _orders([], page: 1, total: 0));
      final page = await _api(t).listPage(search: '  ');
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      final body = t.graphQl.single.body! as Map<String, dynamic>;
      expect((body['variables'] as Map)['search'], isNull);
      // The query has only an asc|desc sort: nothing like createdAt/id.
      expect(body['query'], isNot(contains('order:')));
    });

    test('status filter and pagination errors surface as ApiException',
        () async {
      final t = _Transport((_, __) => _error('Unexpected Execution Error'));
      await expectLater(
          _api(t).list(status: 'Quoted'), throwsA(isA<ApiException>()));
    });

    test('selection excludes MLOR, scores and allocation audit', () async {
      final t = _Transport((_, __) => _orders([], page: 1, total: 0));
      final api = _api(t);
      await api.listPage();
      final lister = (t.graphQl.single.body! as Map)['query'] as String;

      final t2 = _Transport((_, __) => _detail());
      await _api(t2).get(_orderId);
      final detail = (t2.graphQl.single.body! as Map)['query'] as String;

      for (final query in <String>[lister, detail]) {
        for (final forbidden in <String>[
          'mlor',
          'Mlor',
          'weightedScore',
          'distanceScore',
          'coverageScore',
          'shelfLifeScore',
          'allocationAudit',
        ]) {
          expect(query, isNot(contains(forbidden)));
        }
      }
    });
  });

  group('status counts', () {
    test('one request returns every count', () async {
      final t = _Transport((query, vars) {
        expect(query, contains('OrderCounts'));
        const totals = <String, int>{
          'Quoted': 4,
          'PaymentPending': 0,
          'Delivering': 12,
        };
        return ApiResponse(statusCode: 200, data: <String, dynamic>{
          'data': <String, dynamic>{
            'entities': <String, dynamic>{
              for (var i = 0; i < 3; i++)
                'c$i': <String, dynamic>{'totalCount': totals[vars['s$i']]},
            },
          },
        });
      });

      final counts = await _api(t)
          .countsByStatus(<String>['Quoted', 'PaymentPending', 'Delivering']);

      expect(counts, <String, int>{
        'Quoted': 4,
        'PaymentPending': 0,
        'Delivering': 12,
      });
      expect(t.graphQl, hasLength(1));
      expect(t.rest, isEmpty);
    });

    test(
        'statuses the list filter refuses (Delivering) use the entity aggregate, '
        'Sales scoped to its own orders', () async {
      final t = _Transport((query, vars) =>
          const ApiResponse(statusCode: 200, data: <String, dynamic>{
            'data': <String, dynamic>{
              'entities': <String, dynamic>{
                'c0': <String, dynamic>{'totalCount': 4},
                'c1': <String, dynamic>{'totalCount': 9},
              },
            },
          }));
      final counts = await _api(t).countsByStatus(
          <String>['Quoted', 'Delivering'],
          ownerUserId: '33333333-3333-4333-8333-333333333333');

      expect(counts, <String, int>{'Quoted': 4, 'Delivering': 9});
      final body = t.graphQl.single.body! as Map<String, dynamic>;
      final query = body['query'] as String;
      expect(query, contains('c0: orderReads(status: \$s0'));
      expect(query, contains('c1: salesOrders(first: 1'));
      expect(query, contains('createdByUserId: { eq: \$uid }'));
      expect((body['variables'] as Map)['uid'],
          '33333333-3333-4333-8333-333333333333');
    });

    test('Retailer count has no owner filter (scope comes from the Backend)',
        () async {
      final t = _Transport((query, vars) =>
          const ApiResponse(statusCode: 200, data: <String, dynamic>{
            'data': <String, dynamic>{
              'entities': <String, dynamic>{
                'c0': <String, dynamic>{'totalCount': 2},
              },
            },
          }));
      expect(await _api(t).countByStatus('Delivering'), 2);
      final query =
          (t.graphQl.single.body! as Map<String, dynamic>)['query'] as String;
      expect(query, isNot(contains('createdByUserId')));
      expect(query, isNot(contains('\$uid')));
    });

    test('empty input sends nothing; single count keeps working', () async {
      final t = _Transport(
          (_, __) => const ApiResponse(statusCode: 200, data: <String, dynamic>{
                'data': <String, dynamic>{
                  'entities': <String, dynamic>{
                    'c0': <String, dynamic>{'totalCount': 7},
                  },
                },
              }));
      final api = _api(t);
      expect(await api.countsByStatus(<String>[]), isEmpty);
      expect(t.graphQl, isEmpty);
      expect(await api.countByStatus('Quoted'), 7);
    });

    test('a missing total is an error, never a silent zero', () async {
      final t = _Transport(
          (_, __) => const ApiResponse(statusCode: 200, data: <String, dynamic>{
                'data': <String, dynamic>{
                  'entities': <String, dynamic>{'c0': <String, dynamic>{}},
                },
              }));
      await expectLater(
          _api(t).countByStatus('Quoted'), throwsA(isA<ApiException>()));
    });

    test('a GraphQL error fails the counts', () async {
      final t = _Transport((_, __) => _error('boom'));
      await expectLater(_api(t).countsByStatus(<String>['Quoted']),
          throwsA(isA<ApiException>()));
    });
  });

  group('detail', () {
    test('by id is read through GraphQL and keeps lines, promotion, batches',
        () async {
      final t = _Transport((_, __) => _detail());

      final order = await _api(t).get(_orderId);

      expect(order.code, 'DH-1');
      expect(order.total, 1000);
      expect(order.discount, 100);
      expect(order.version, 3);
      expect(order.lines.single.sku, 'S1');
      expect(order.lines.single.qty, 10);
      expect(order.lines.single.promoName, 'Khuyến mãi A');
      expect(order.lines.single.batches.single.batchCode, 'B1');
      expect(order.lines.single.batches.single.hasPriceSnapshot, isTrue);
      expect(order.timeline, hasLength(1));
      expect(t.rest, isEmpty);
      expect(((t.graphQl.single.body! as Map)['query'] as String),
          contains('orderRead(id: "$_orderId")'));
    });

    test('by code stays REST and sends no GraphQL', () async {
      final t = _Transport((_, __) => _error('unused'),
          onRest: (_) => ApiResponse(statusCode: 200, data: _detailJson()));

      final order = await _api(t).get('DH-1');

      expect(order.code, 'DH-1');
      expect(t.graphQl, isEmpty);
      expect(t.restCalls, 'GET /orders/by-code/DH-1');
    });

    test('generic GraphQL failure falls back to REST by id', () async {
      final t = _Transport((_, __) => _error('Unexpected Execution Error'),
          onRest: (_) => ApiResponse(statusCode: 200, data: _detailJson()));

      final order = await _api(t).get(_orderId);

      expect(order.code, 'DH-1');
      expect(t.restCalls, 'GET /orders/$_orderId');
    });

    test('authorization and network failures do not fall back', () async {
      final forbidden =
          _Transport((_, __) => _error('no', 'AUTH_NOT_AUTHORIZED'));
      await expectLater(
          _api(forbidden).get(_orderId),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)));
      expect(forbidden.rest, isEmpty);

      final api = ApiClient(transport: _Offline(), tokenReader: () => 'token');
      addTearDown(api.dispose);
      await expectLater(OrdersApi(api).get(_orderId),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });
  });

  group('writes stay REST', () {
    test('create, cancel and retry allocation never touch GraphQL', () async {
      final t = _Transport((_, __) => _error('unused'),
          onRest: (_) => ApiResponse(statusCode: 200, data: _detailJson()));
      final api = _api(t);

      await api.create(const NewOrderRequest(
        clientOrderKey: _orderId,
        retailerId: 'r1',
        lines: [CartLine(productId: 'p1', sku: 'S1', qty: 10)],
      ));
      await api.cancel('id-1', 3);
      await api.retryAllocation('id-1', 3);

      expect(t.graphQl, isEmpty);
      expect(t.restCalls,
          'POST /orders,POST /orders/id-1/cancel,POST /orders/id-1/allocation/retry');
      expect((t.rest[1].body as Map)['expectedVersion'], 3);
      expect((t.rest[2].body as Map)['expectedVersion'], 3);
    });
  });

  group('offline queue merge', () {
    late AppDatabase database;
    late OfflineOrderDao queue;

    Future<OrderRepository> repository(_Transport t) async {
      SharedPreferences.setMockInitialValues({'device_code': 'TEST'});
      final name = 'orders_gql_${DateTime.now().microsecondsSinceEpoch}.db';
      database = AppDatabase(databaseName: name);
      queue = OfflineOrderDao(database);
      final client = ApiClient(transport: t, tokenReader: () => 'token');
      addTearDown(() async {
        client.dispose();
        await database.close();
        await deleteDatabase(p.join(await getDatabasesPath(), name));
      });
      return OrderRepository(
        api: OrdersApi(client),
        queue: queue,
        syncState: SyncStateDao(database),
        device: DeviceIdentity(await SharedPreferences.getInstance()),
        ownerId: 'sales',
        isSales: true,
        isCurrentUser: () => true,
      );
    }

    Future<void> pendingOrder(OrderRepository repo) async {
      const request = NewOrderRequest(
        clientOrderKey: '22222222-2222-4222-8222-222222222222',
        retailerId: 'retailer-id',
        lines: [CartLine(productId: 'product-id', sku: 'SKU001', qty: 10)],
      );
      await repo.createOffline(
        orderStep: 1,
        retailer: Retailer.fromJson({
          'id': 'retailer-id',
          'code': 'RT001',
          'name': 'T',
          'address': 'A'
        }),
        lines: request.lines,
        estimate: const PriceQuote(lines: [
          QuoteLine(
              sku: 'SKU001', name: 'P', qty: 10, unitPrice: 100, discount: 0)
        ], applied: [], total: 1000, discount: 0),
        estimatedAt: DateTime.now(),
        snapshot: null,
        pendingOnlineRequest: request,
      );
    }

    test('pending local order is kept next to every server page, no duplicates',
        () async {
      final t = _Transport((_, vars) {
        final page = vars['page'] as int;
        final first = (page - 1) * 100;
        final count = page == 3 ? 50 : 100;
        return _orders([for (var i = 0; i < count; i++) _summary(first + i)],
            page: page, total: 250, pageSize: 100);
      });
      final repo = await repository(t);
      await pendingOrder(repo);

      final result = await repo.listOrders(includeQueue: true);

      expect(t.graphQl.map((r) => (r.body as Map)['variables']['page']),
          [1, 2, 3]);
      expect(result.offlineOnly, isFalse);
      expect(result.orders, hasLength(251));
      final pending = result.orders.where((o) => o.isOffline).toList();
      expect(pending, hasLength(1));
      expect(pending.single.syncStatus, isNotNull);
      expect(pending.single.id, isEmpty); // not a server-confirmed order
      final codes = result.orders.map((o) => o.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
      final dates = result.orders.map((o) => o.createdAt).toList();
      expect(dates, orderedEquals([...dates]..sort((a, b) => b.compareTo(a))));
    });

    test('server unreachable: pending order retained, flagged offline only',
        () async {
      final repo = await repository(_Transport((_, __) => _error('x')));
      await pendingOrder(repo);
      // Replace the transport behavior with a network failure.
      final offlineRepo = OrderRepository(
        api: OrdersApi(
            ApiClient(transport: _Offline(), tokenReader: () => 'token')),
        queue: queue,
        syncState: SyncStateDao(database),
        device: DeviceIdentity(await SharedPreferences.getInstance()),
        ownerId: 'sales',
        isSales: true,
        isCurrentUser: () => true,
      );

      final result = await offlineRepo.listOrders(includeQueue: true);

      expect(result.offlineOnly, isTrue);
      expect(result.orders.single.isOffline, isTrue);
      expect((await queue.all(ownerId: 'sales')), hasLength(1));
    });

    test('a server error other than network is not hidden as offline',
        () async {
      final repo = await repository(_Transport((_, __) => _error('boom')));
      await pendingOrder(repo);
      await expectLater(
          repo.listOrders(includeQueue: true), throwsA(isA<ApiException>()));
      expect((await queue.all(ownerId: 'sales')), hasLength(1));
    });
  });
}

class _Offline implements ApiTransport {
  @override
  Future<ApiResponse> send(ApiRequest request) async =>
      throw const ApiException.network();
}
