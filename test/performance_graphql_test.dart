import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/remote/performance_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';

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
}

ApiResponse _data(String field, Map<String, dynamic> result) =>
    ApiResponse(statusCode: 200, data: <String, dynamic>{
      'data': <String, dynamic>{field: result},
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

Map<String, dynamic> _metric() => <String, dynamic>{
      'code': 'promotionRevenueRatio',
      'name': 'Tỷ lệ khuyến mãi',
      'target': 0.1,
      'actual': 0.05,
      'completionRate': 1.0,
      'weight': 0.25,
      'weightedScore': 0.25,
      'unit': 'ratio',
    };

Map<String, dynamic> _order() => <String, dynamic>{
      'orderId': 'order-1',
      'orderCode': 'DH-001',
      'retailerId': 'r1',
      'retailerCode': '1001',
      'retailerName': 'Điểm bán',
      'recognitionDate': '2026-11-11',
      'revenueBeforePromotion': 1100.75,
      'promotionAmount': 100.25,
      'revenueAfterPromotion': 1000.5,
      'approvedAdjustmentAmount': 50.25,
      'recognizedRevenue': 950.25,
    };

Map<String, dynamic> _kpi(String from, String to,
        {List<Map<String, dynamic>>? entries}) =>
    <String, dynamic>{
      'fromDate': from,
      'toDate': to,
      'scope': 'OwnGroup',
      'configurationVersion': 3,
      'configurationEffectiveFrom': '2026-10-31T17:00:00Z',
      'recognitionRule': 'Delivered order',
      'entries': entries ??
          <Map<String, dynamic>>[
            <String, dynamic>{
              'salesUserId': 'me',
              'salesGroupId': 'g1',
              'salesGroupName': 'Nhóm',
              'overallCompletionRate': 0.8125,
              'recognizedRevenue': 950.25,
              'metrics': [_metric()],
              'orders': [_order()],
            },
          ],
    };

Map<String, dynamic> _products(String from, String to, String criterion,
        List<Map<String, dynamic>> entries) =>
    <String, dynamic>{
      'fromDate': from,
      'toDate': to,
      'criterion': criterion,
      'scope': 'OwnGroup',
      'entries': entries,
    };

Map<String, dynamic> _product(int rank, String sku, num qty, num revenue) =>
    <String, dynamic>{
      'rank': rank,
      'sku': sku,
      'productName': 'Sản phẩm $sku',
      'normalizedSoldQuantity': qty,
      'quantityUnit': 'carton',
      'adjustedNetRevenue': revenue,
    };

PerformanceApi _api(_Transport t) {
  final client = ApiClient(transport: t, tokenReader: () => 'token');
  addTearDown(client.dispose);
  return PerformanceApi(client);
}

const _period = PerformancePeriod('2026-11-01', '2026-11-11');

void main() {
  group('Sales KPI', () {
    test('GraphQL query: inclusive dates as literals, no client scope',
        () async {
      final t = _Transport(
          onGraphQl: (_) =>
              _data('salesKpis', _kpi('2026-11-01', '2026-11-11')));

      final kpi = await _api(t).kpi(_period);

      expect(t.rest, isEmpty);
      expect(
          t.query,
          contains(
              'salesKpis(query: { fromDate: "2026-11-01", toDate: "2026-11-11" })'));
      expect(t.query, isNot(contains('salesUserId: "')));
      expect(t.query, isNot(contains('salesGroupId: "')));
      expect((t.graphQl.single.body! as Map)['operationName'], 'SalesKpi');
      // Only what the app reads; nothing internal.
      expect(t.query, isNot(contains('regionId')));
      expect(t.query, isNot(contains('salesUserName')));
      expect(kpi.fromDate, '2026-11-01');
      expect(kpi.toDate, '2026-11-11');
    });

    test('maps backend values without recalculating', () async {
      final t = _Transport(
          onGraphQl: (_) =>
              _data('salesKpis', _kpi('2026-11-01', '2026-11-11')));
      final kpi = await _api(t).kpi(_period);

      final entry = kpi.entries.single;
      expect(kpi.configurationVersion, 3);
      expect(entry.recognizedRevenue, 950.25);
      expect(entry.overallCompletionRate, 0.8125);
      expect(entry.metrics.single.target, 0.1);
      expect(entry.metrics.single.weightedScore, 0.25);
      expect(entry.orders.single.id, 'order-1');
      expect(entry.orders.single.adjustment, 50.25);
      expect(entry.orders.single.recognizedRevenue, 950.25);
    });

    test('empty result is an empty KPI, not an error', () async {
      final t = _Transport(
          onGraphQl: (_) => _data(
              'salesKpis', _kpi('2026-11-01', '2026-11-11', entries: [])));
      expect((await _api(t).kpi(_period)).entries, isEmpty);
    });

    test('a different period in the answer is an error and is not retried',
        () async {
      final t = _Transport(
          onGraphQl: (_) =>
              _data('salesKpis', _kpi('2026-10-01', '2026-10-31')),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(t).kpi(_period), throwsA(isA<ApiException>()));
      expect(t.rest, isEmpty);
    });

    test('malformed GraphQL data is an error, not a zero KPI', () async {
      final t = _Transport(
          onGraphQl: (_) =>
              const ApiResponse(statusCode: 200, data: <String, dynamic>{
                'data': <String, dynamic>{'salesKpis': null},
              }),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(t).kpi(_period), throwsA(isA<ApiException>()));
    });

    test('generic GraphQL error is re-read through REST for the real message',
        () async {
      final t = _Transport(
        onGraphQl: (_) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(
            statusCode: 200, data: _kpi('2026-11-01', '2026-11-11')),
      );
      final kpi = await _api(t).kpi(_period);
      expect(kpi.entries, hasLength(1));
      expect(t.rest.single.path, '/reports/sales-kpis');
      expect(t.rest.single.query!['fromDate'], '2026-11-01');
      expect(t.rest.single.query!['toDate'], '2026-11-11');
    });

    test('REST error after the fallback is what the user sees', () async {
      final t = _Transport(
        onGraphQl: (_) => _errors('Unexpected Execution Error'),
        onRest: (_) => const ApiResponse(
            statusCode: 400,
            data: <String, dynamic>{
              'detail': 'The period cannot start in the future.'
            }),
      );
      await expectLater(
          _api(t).kpi(_period),
          throwsA(isA<ApiException>()
              // The REST answer (not the GraphQL error) is what surfaces; its
              // English text is shown in Vietnamese and kept in `details`.
              .having((e) => e.details, 'original', contains('cannot start'))
              .having((e) => e.message, 'message', contains('tương lai'))));
    });

    test('authorization and network failures do not fall back', () async {
      final forbidden = _Transport(
          onGraphQl: (_) => _errors('no', 'AUTH_NOT_AUTHORIZED'),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(
          _api(forbidden).kpi(_period),
          throwsA(isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)));

      final offline = _Transport(
          onGraphQl: (_) => throw const ApiException.network(),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(offline).kpi(_period),
          throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)));
    });
  });

  group('date range (Vietnam, UTC+7, inclusive)', () {
    test('midnight and end of day', () {
      // 16:59:59Z is 23:59:59 in Vietnam, 17:00:00Z is already the next day.
      expect(
          PerformancePeriod.forKey(
                  'today', DateTime.utc(2026, 11, 19, 16, 59, 59))
              .fromDate,
          '2026-11-19');
      expect(
          PerformancePeriod.forKey('today', DateTime.utc(2026, 11, 19, 17))
              .fromDate,
          '2026-11-20');
      expect(
          PerformancePeriod.forKey('today', DateTime.utc(2026, 11, 19, 17))
              .toDate,
          '2026-11-20');
      expect(
          PerformancePeriod.forKey(
                  'today', DateTime.utc(2026, 11, 19, 16, 59, 59))
              .toDate,
          '2026-11-19');
    });

    test('week is seven calendar days ending today (inclusive)', () {
      final week =
          PerformancePeriod.forKey('week', DateTime.utc(2026, 11, 19, 17));
      expect(week.fromDate, '2026-11-14');
      expect(week.toDate, '2026-11-20');
    });

    test('month, last month and quarter at year and month ends', () {
      final lateDec = DateTime.utc(2026, 12, 31, 17); // 1 Jan 2027, Vietnam
      expect(PerformancePeriod.forKey('month', lateDec).fromDate, '2027-01-01');
      expect(
          PerformancePeriod.forKey('lastMonth', lateDec).toDate, '2026-12-31');
      expect(
          PerformancePeriod.forKey('quarter', lateDec).fromDate, '2027-01-01');
      final endNov = DateTime.utc(2026, 11, 30, 16, 59); // still 30 Nov
      expect(PerformancePeriod.forKey('month', endNov).toDate, '2026-11-30');
      expect(
          PerformancePeriod.forKey('lastMonth', endNov).toDate, '2026-10-31');
    });

    test('the document carries the period exactly, and bad dates never do',
        () async {
      final t = _Transport(
          onGraphQl: (_) =>
              _data('salesKpis', _kpi('2026-11-20', '2026-11-20')));
      final period =
          PerformancePeriod.forKey('today', DateTime.utc(2026, 11, 19, 17));
      await _api(t).kpi(period);
      expect(t.query, contains('fromDate: "2026-11-20", toDate: "2026-11-20"'));

      for (final bad in <PerformancePeriod>[
        const PerformancePeriod('', '2026-11-11'),
        const PerformancePeriod('2026-11-01', 'tomorrow'),
        const PerformancePeriod('2026-11-01", x: "', '2026-11-11'),
      ]) {
        await expectLater(_api(t).kpi(bad), throwsA(isA<ArgumentError>()));
      }
      expect(t.graphQl, hasLength(1)); // nothing invalid was sent
    });

    test('unknown period keys are rejected', () {
      expect(() => PerformancePeriod.forKey('year', DateTime.utc(2026)),
          throwsArgumentError);
    });
  });

  group('Best-selling products', () {
    test('query carries period and criterion; no paging arguments', () async {
      final t = _Transport(
          onGraphQl: (_) => _data(
              'bestSellingProducts',
              _products('2026-11-01', '2026-11-11', 'Revenue',
                  [_product(1, 'SKU-1', 10, 5000)])));

      await _api(t).productRanking(_period, 'Revenue');

      expect(t.rest, isEmpty);
      expect(t.query, contains('bestSellingProducts(query: '));
      expect(
          t.query,
          contains(
              'fromDate: "2026-11-01", toDate: "2026-11-11", criterion: "Revenue"'));
      for (final invented in <String>['first:', 'after:', 'page', 'pageSize']) {
        expect(t.query, isNot(contains(invented)));
      }
    });

    test('keeps backend order, quantity and revenue', () async {
      final t = _Transport(
          onGraphQl: (_) => _data(
              'bestSellingProducts',
              _products('2026-11-01', '2026-11-11', 'Quantity', [
                _product(1, 'SKU-B', 120.5, 900),
                _product(2, 'SKU-A', 120.5, 1000),
                _product(3, 'SKU-C', 3, 99999),
              ])));

      final report = await _api(t).productRanking(_period, 'Quantity');

      // Ranking and ties are the Backend's: order is not re-sorted here.
      expect(report.entries.map((e) => e.sku), ['SKU-B', 'SKU-A', 'SKU-C']);
      expect(report.entries.map((e) => e.rank), [1, 2, 3]);
      expect(report.entries.first.quantity, 120.5);
      expect(report.entries.first.adjustedNetRevenue, 900);
      expect(report.entries.last.unit, 'carton');
      expect(report.entries.first.name, 'Sản phẩm SKU-B');
    });

    test('empty result', () async {
      final t = _Transport(
          onGraphQl: (_) => _data('bestSellingProducts',
              _products('2026-11-01', '2026-11-11', 'Revenue', [])));
      expect(
          (await _api(t).productRanking(_period, 'Revenue')).entries, isEmpty);
    });

    test('criterion in the answer must match; unknown criterion is rejected',
        () async {
      final wrong = _Transport(
          onGraphQl: (_) => _data('bestSellingProducts',
              _products('2026-11-01', '2026-11-11', 'Quantity', [])),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(wrong).productRanking(_period, 'Revenue'),
          throwsA(isA<ApiException>()));
      await expectLater(
          _api(wrong).productRanking(_period, 'Profit'), throwsArgumentError);
      expect(wrong.graphQl, hasLength(1));
    });

    test('errors: generic falls back to REST, authorization does not',
        () async {
      final t = _Transport(
        onGraphQl: (_) => _errors('Unexpected Execution Error'),
        onRest: (_) => ApiResponse(
            statusCode: 200,
            data: _products('2026-11-01', '2026-11-11', 'Revenue',
                [_product(1, 'SKU-1', 1, 2)])),
      );
      expect((await _api(t).productRanking(_period, 'Revenue')).entries,
          hasLength(1));
      expect(t.rest.single.path, '/reports/best-selling-products');
      expect(t.rest.single.query!['criterion'], 'Revenue');

      final denied = _Transport(
          onGraphQl: (_) => _errors('no', 'AUTH_NOT_AUTHORIZED'),
          onRest: (_) => throw StateError('must not fall back'));
      await expectLater(_api(denied).productRanking(_period, 'Revenue'),
          throwsA(isA<ApiException>()));
    });
  });

  group('Sales ranking stays REST', () {
    test('no GraphQL request is made', () async {
      final t = _Transport(
          onRest: (_) =>
              const ApiResponse(statusCode: 200, data: <String, dynamic>{
                'fromDate': '2026-11-01',
                'toDate': '2026-11-11',
                'scope': 'OwnGroup',
                'entries': <Object>[],
              }));
      final report = await _api(t).salesRanking(_period);
      expect(report.entries, isEmpty);
      expect(t.graphQl, isEmpty);
      expect(t.rest.single.path, '/reports/sales-ranking');
    });
  });

  group('state', () {
    test('one request per period; changing the period asks again', () async {
      final t = _Transport(onGraphQl: (query) {
        final dates = RegExp(r'fromDate: "([^"]+)", toDate: "([^"]+)"')
            .firstMatch(query)!;
        return _data('salesKpis', _kpi(dates.group(1)!, dates.group(2)!));
      });
      final client = ApiClient(transport: t, tokenReader: () => 'token');
      addTearDown(client.dispose);
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(const AppUser(
            id: 'me',
            fullName: 'S',
            phone: '0',
            role: UserRole.sales,
            permissions: ['mobile-sales-kpi'])),
        performanceApiProvider.overrideWithValue(PerformanceApi(client)),
      ]);
      addTearDown(container.dispose);
      final sub1 = container.listen(salesKpiProvider('month'), (_, __) {});
      final sub2 = container.listen(salesKpiProvider('month'), (_, __) {});
      addTearDown(sub1.close);
      addTearDown(sub2.close);

      await container.read(salesKpiProvider('month').future);
      await container.read(salesKpiProvider('month').future);
      expect(t.graphQl, hasLength(1)); // no duplicate request

      final sub3 = container.listen(salesKpiProvider('week'), (_, __) {});
      addTearDown(sub3.close);
      await container.read(salesKpiProvider('week').future);
      expect(t.graphQl, hasLength(2));
      expect(t.query,
          isNot(contains((t.graphQl.first.body! as Map)['query'] as String)));
    });

    test('a non-Sales user cannot read a personal KPI', () async {
      final t = _Transport(onGraphQl: (_) => throw StateError('no request'));
      final repository =
          PerformanceRepository(_api(t), userId: 'x', isSales: false);
      await expectLater(repository.kpi('month'), throwsA(isA<ApiException>()));
      expect(t.graphQl, isEmpty);
    });
  });
}
