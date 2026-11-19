import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/remote/receivables_api.dart';

Map<String, dynamic> _row(int i) => <String, dynamic>{
      'id': 'p-$i',
      'orderId': 'o-$i',
      'orderCode': 'DH-$i',
      'status': 'Open',
      'collectibleAmount': 1000,
    };

/// Serves `total` rows in pages of the requested size.
class _Server implements ApiTransport {
  _Server(this.total, {this.pageOverride, this.failOnPage});

  final int total;
  final List<int> Function(int page)? pageOverride;
  final int? failOnPage;
  final List<int> pagesRequested = <int>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final vars = (request.body! as Map<String, dynamic>)['variables']
        as Map<String, dynamic>;
    final page = vars['page'] as int;
    final size = vars['pageSize'] as int;
    pagesRequested.add(page);
    if (page == failOnPage) throw const ApiException.network();
    final ids = pageOverride?.call(page) ??
        <int>[
          for (var i = (page - 1) * size; i < page * size && i < total; i++) i
        ];
    return ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'retailerReceivables': <String, dynamic>{
          'items': ids.map(_row).toList(),
          'page': page,
          'pageSize': size,
          'totalCount': total,
          'totalPages': (total / size).ceil(),
        },
      },
    });
  }
}

Future<List<String>> _load(_Server server) async {
  final client = ApiClient(transport: server, tokenReader: () => 'token');
  addTearDown(client.dispose);
  final rows = await ReceivablesApi(client).list(retailer: true);
  return rows.map((r) => r.paymentId).toList();
}

void main() {
  test('uses the configured GraphQL endpoint', () async {
    final seen = <String>[];
    final client = ApiClient(transport: _Spy(seen), tokenReader: () => 'token');
    addTearDown(client.dispose);
    await ReceivablesApi(client).list(retailer: true);
    expect(seen.single, Env.effectiveGraphQlEndpoint);
  });

  test('loads every page when there are more than 100 records', () async {
    final server = _Server(250);
    final ids = await _load(server);
    expect(ids, hasLength(250));
    expect(ids.toSet(), hasLength(250));
    expect(server.pagesRequested, [1, 2, 3]);
  });

  test('exact multiple of the page size does not request an empty page',
      () async {
    final server = _Server(200);
    expect(await _load(server), hasLength(200));
    expect(server.pagesRequested, [1, 2]);
  });

  test('no records', () async {
    final server = _Server(0);
    expect(await _load(server), isEmpty);
    expect(server.pagesRequested, [1]);
  });

  test('empty page before totalCount ends the loop', () async {
    final server = _Server(300,
        pageOverride: (page) => page == 1 ? <int>[0, 1, 2] : <int>[]);
    expect(await _load(server), hasLength(3));
    expect(server.pagesRequested, [1, 2]);
  });

  test('rows repeated across pages are returned once', () async {
    final server = _Server(5, pageOverride: (page) => <int>[0, 1, 2]);
    // total 5 but the server keeps repeating the same page: stop, no loop.
    final ids = await _load(server);
    expect(ids, ['p-0', 'p-1', 'p-2']);
    expect(server.pagesRequested.length, lessThanOrEqualTo(2));
  });

  test('overlapping pages are de-duplicated', () async {
    final server = _Server(150, pageOverride: (page) {
      return page == 1
          ? <int>[for (var i = 0; i < 100; i++) i]
          : <int>[for (var i = 90; i < 150; i++) i];
    });
    final ids = await _load(server);
    expect(ids, hasLength(150));
    expect(ids.toSet(), hasLength(150));
  });

  test('an error on a later page fails the whole load', () async {
    final server = _Server(250, failOnPage: 2);
    await expectLater(_load(server), throwsA(isA<ApiException>()));
  });
}

class _Spy implements ApiTransport {
  _Spy(this.paths);
  final List<String> paths;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    paths.add(request.path);
    return const ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{
        'retailerReceivables': <String, dynamic>{
          'items': <Object>[],
          'totalCount': 0,
        },
      },
    });
  }
}
