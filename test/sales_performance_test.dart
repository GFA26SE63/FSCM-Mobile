import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/remote/performance_api.dart';
import 'package:fscm_mobile/data/repositories/performance_repository.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/kpi_content.dart';
import 'package:fscm_mobile/features/sales/kpi/widgets/ranking_content.dart';

Map<String, dynamic> envelope(List<Map<String, dynamic>> entries) => {
      'fromDate': '2026-11-01',
      'toDate': '2026-11-11',
      'scope': 'OwnGroup',
      'entries': entries,
      'configurationVersion': 3,
      'configurationEffectiveFrom': '2026-10-31T17:00:00Z',
      'recognitionRule': 'Completed',
    };

Map<String, dynamic> metric() => {
      'code': 'promotionRevenueRatio',
      'name': 'Tỷ lệ khuyến mãi trên doanh thu',
      'target': 0.1,
      'actual': 0.05,
      'completionRate': 1.0,
      'weight': 0.25,
      'weightedScore': 0.25,
      'unit': 'ratio',
    };

Map<String, dynamic> order() => {
      'orderId': 'order-1',
      'orderCode': 'DH-001',
      'retailerId': 'retailer-1',
      'retailerCode': '1001',
      'retailerName': 'Điểm bán có tên rất dài để kiểm tra trên điện thoại',
      'recognitionDate': '2026-11-11',
      'revenueBeforePromotion': 1100.75,
      'promotionAmount': 100.25,
      'revenueAfterPromotion': 1000.5,
      'approvedAdjustmentAmount': 50.25,
      'recognizedRevenue': 950.25,
    };

Map<String, dynamic> entry({String userId = 'me'}) => {
      'salesUserId': userId,
      'salesGroupId': 'group-1',
      'salesGroupName': 'Nhóm Sales có tên dài',
      'overallCompletionRate': 0.8125,
      'recognizedRevenue': 950.25,
      'metrics': [metric()],
      'orders': [order()],
    };

void main() {
  test('calendar periods use Vietnam midnight and handle previous year', () {
    final instant = DateTime.parse('2026-12-31T17:05:00Z');
    final month = PerformancePeriod.forKey('month', instant);
    expect(month.fromDate, '2027-01-01');
    expect(month.toDate, '2027-01-01');
    final last = PerformancePeriod.forKey('lastMonth', instant);
    expect(last.fromDate, '2026-12-01');
    expect(last.toDate, '2026-12-31');
    expect(PerformancePeriod.forKey('week', instant).fromDate, '2026-12-26');
    expect(PerformancePeriod.forKey('quarter', instant).fromDate, '2027-01-01');
  });

  test('preserves backend ratios, adjustments, order linkage and decimals', () {
    final report = SalesKpi.fromJson(envelope([entry()]), DateTime.utc(2026));
    expect(report.entries.single.recognizedRevenue, 950.25);
    expect(report.entries.single.overallCompletionRate, 0.8125);
    expect(report.entries.single.metrics.single.target, 0.1);
    expect(report.entries.single.orders.single.id, 'order-1');
    expect(report.entries.single.orders.single.adjustment, 50.25);
  });

  test('missing entries or metric values are errors, not zero KPI', () {
    final malformed = envelope([entry()])..remove('entries');
    expect(() => SalesKpi.fromJson(malformed, DateTime.utc(2026)),
        throwsA(isA<ApiException>()));
    final broken = entry();
    broken['metrics'] = [metric()..remove('actual')];
    expect(() => SalesKpi.fromJson(envelope([broken]), DateTime.utc(2026)),
        throwsA(isA<ApiException>()));
    expect(
        SalesKpi.fromJson(envelope([]), DateTime.utc(2026)).entries, isEmpty);
  });

  test('calls current report endpoints with inclusive dates and criterion',
      () async {
    final transport = ReportTransport((request) {
      final data = envelope([]);
      if (request.path.endsWith('best-selling-products')) {
        data['criterion'] = 'Revenue';
      }
      return ApiResponse(statusCode: 200, data: data);
    });
    final api = PerformanceApi(
        ApiClient(transport: transport, tokenReader: () => null));
    const period = PerformancePeriod('2026-11-01', '2026-11-11');
    await api.kpi(period);
    await api.salesRanking(period);
    await api.productRanking(period, 'Revenue');
    expect(transport.requests.map((r) => r.path), [
      '/reports/sales-kpis',
      '/reports/sales-ranking',
      '/reports/best-selling-products',
    ]);
    for (final request in transport.requests) {
      expect(request.query!['fromDate'], period.fromDate);
      expect(request.query!['toDate'], period.toDate);
      expect(request.query!.containsKey('period'), isFalse);
      expect(request.query!.containsKey('salesUserId'), isFalse);
    }
    expect(transport.requests.last.query!['criterion'], 'Revenue');
  });

  test('forbidden reports propagate and non-Sales cannot request personal KPI',
      () async {
    final transport = ReportTransport((_) =>
        const ApiResponse(statusCode: 403, data: {'title': 'Forbidden'}));
    final api = PerformanceApi(
        ApiClient(transport: transport, tokenReader: () => null));
    final denied =
        PerformanceRepository(api, userId: 'retailer', isSales: false);
    await expectLater(denied.kpi('month'), throwsA(isA<ApiException>()));
    expect(transport.requests, isEmpty);
    await expectLater(
        api.kpi(const PerformancePeriod('2026-11-01', '2026-11-11')),
        throwsA(isA<ApiException>()));
  });

  test('personal KPI rejects data belonging to another Sales', () async {
    final transport =
        ReportTransport((request) => ApiResponse(statusCode: 200, data: {
              ...envelope([entry(userId: 'other')]),
              'fromDate': request.query!['fromDate'],
              'toDate': request.query!['toDate'],
            }));
    final repository = PerformanceRepository(
        PerformanceApi(
            ApiClient(transport: transport, tokenReader: () => null)),
        userId: 'me',
        isSales: true);
    await expectLater(repository.kpi('month'), throwsA(isA<ApiException>()));
  });

  testWidgets(
      'KPI shows server targets and keeps retailer and order detail on narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final report = SalesKpi.fromJson(envelope([entry()]), DateTime.utc(2026));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: KpiContent(report: report))))));
    expect(find.text('81,3%'), findsOneWidget);
    expect(find.text('Ngưỡng tối đa'), findsOneWidget);
    expect(find.text('10,0%'), findsOneWidget);
    expect(find.text('Theo điểm bán'), findsOneWidget);
    expect(find.text('DH-001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking highlights current user by ID and keeps server rank',
      (tester) async {
    final report = PerformanceReport<RankingEntry>.fromJson(
        envelope([
          {
            'rank': 7,
            'salesUserId': 'me',
            'salesGroupId': 'group-1',
            'salesUserName': 'Hoàng',
            'salesGroupName': 'Nhóm A',
            'orderCount': 2,
            'recognizedRevenue': 950.25,
          }
        ]),
        RankingEntry.fromJson,
        DateTime.utc(2026));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SalesRankingContent(report: report, userId: 'me')))));
    expect(find.text('Vị trí của bạn · Nhóm A: #7'), findsOneWidget);
    expect(find.text('#7 · Hoàng (bạn)'), findsOneWidget);
    expect(find.textContaining('Tháng 9'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class ReportTransport implements ApiTransport {
  ReportTransport(this.respond);
  final ApiResponse Function(ApiRequest) respond;
  final requests = <ApiRequest>[];
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return respond(request);
  }
}
