import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';

// MOB-04.2: the shared Sales/Retailer detail read (`OrdersApi.get` →
// GraphQL `orderRead`) did not select `ordinaryPromotion.discountPercent`, so
// the real server never returned it and promoPct was always null.
const _orderId = '11111111-1111-4111-8111-111111111111';

/// Backend `OrderOrdinaryPromotionSnapshotResult` as the server holds it.
Map<String, dynamic> _promotion(String name, num pct, int amount) => {
      'promotionId': 'p-$name',
      'code': 'KM-$name',
      'name': name,
      'type': 'Campaign',
      'minimumQuantity': 1,
      'discountPercent': pct,
      'discountAmount': amount,
    };

/// Backend `OrderDetailResult` lines (owner's Demo_Demo1 order + extra cases).
Map<String, dynamic> _serverOrder() => {
      'id': _orderId,
      'orderCode': 'DH-000777',
      'retailerId': 'r1',
      'retailerCode': 'RT1',
      'retailerName': 'Retailer',
      'createdByUserId': 'sales-a',
      'status': 'Quoted',
      'paymentMethod': 'Prepaid',
      'subtotalAmount': 3400,
      'discountAmount': 480,
      'finalAmount': 2920,
      'version': 1,
      'source': 'Online',
      'createdAt': '2026-11-20T03:00:00Z',
      'lines': [
        // Promotion 10% (120đ) + HSD on 1.080 VND (160đ) = 280 VND (23,33%).
        {
          'sku': 'X', 'productName': 'SP X', 'quantity': 5, 'unitPrice': 240,
          'grossAmount': 1200, 'discountAmount': 280, 'discountPercent': 23.33,
          'netAmount': 920, 'discountSourceType': 'ShelfLife',
          'discountSourceCode': 'HSD-V2',
          'ordinaryPromotion': _promotion('Demo_Demo1', 10, 120),
        },
        // Different promotion, fractional rate.
        {
          'sku': 'Y', 'productName': 'SP Y', 'quantity': 4, 'unitPrice': 200,
          'grossAmount': 800, 'discountAmount': 100, 'discountPercent': 12.5,
          'netAmount': 700, 'discountSourceType': 'Campaign',
          'discountSourceCode': 'KM-Demo_Demo2',
          'ordinaryPromotion': _promotion('Demo_Demo2', 12.5, 100),
        },
        // HSD only, no promotion.
        {
          'sku': 'Z', 'productName': 'SP Z', 'quantity': 7, 'unitPrice': 200,
          'grossAmount': 1400, 'discountAmount': 100, 'discountPercent': 7.14,
          'netAmount': 1300, 'discountSourceType': 'ShelfLife',
          'discountSourceCode': 'HSD-V2', 'ordinaryPromotion': null,
        },
      ],
    };

/// Answers like a GraphQL server: an `ordinaryPromotion` field is returned
/// only when the query selects it.
class _GraphQlServer implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.path != Env.effectiveGraphQlEndpoint) {
      return ApiResponse(statusCode: 200, data: _serverOrder()); // REST: full DTO
    }
    final query = (request.body! as Map<String, dynamic>)['query'] as String;
    final selection = RegExp(r'ordinaryPromotion\s*\{([^}]*)\}')
        .firstMatch(query)!
        .group(1)!
        .split(RegExp(r'\s+'))
        .where((f) => f.isNotEmpty)
        .toSet();
    final order = _serverOrder();
    // Top-level creator id is returned only when selected (as GraphQL does).
    if (!query.contains('createdByUserId')) {
      order.remove('createdByUserId');
    }
    for (final line in order['lines'] as List) {
      final promo = (line as Map<String, dynamic>)['ordinaryPromotion'];
      if (promo is Map<String, dynamic>) {
        promo.removeWhere((k, _) => !selection.contains(k));
      }
    }
    return ApiResponse(statusCode: 200, data: {
      'data': {
        'entities': {'orderRead': order}
      }
    });
  }
}

Future<Order> _fetch(String idOrCode) {
  final client = ApiClient(transport: _GraphQlServer(), tokenReader: () => 't');
  addTearDown(client.dispose);
  return OrdersApi(client).get(idOrCode);
}

Future<void> _render(WidgetTester tester, Order order) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(child: OrderLinesCard(order)))));
}

void main() {
  test('GraphQL detail read maps the promotion rate (Sales + Retailer path)',
      () async {
    final order = await _fetch(_orderId);
    expect(order.lines.map((l) => l.promoPct), [10, 12.5, null]);
    expect(order.lines.map((l) => l.promoName),
        ['Demo_Demo1', 'Demo_Demo2', 'Giảm giá theo HSD']);
    // Combined line rate stays separate and money is untouched.
    expect(order.lines.map((l) => l.discountPct), [23.33, 12.5, 7.14]);
    expect(order.lines.map((l) => l.discount), [280, 100, 100]);
    expect(order.lines.map((l) => l.net), [920, 700, 1300]);
    expect(order.lines.first.campaignDiscount, 120);
    expect(order.lines.first.shelfLifeDiscount, 160);
  });

  test('REST detail read (by order code) maps the same rate', () async {
    final order = await _fetch('DH-000777');
    expect(order.lines.map((l) => l.promoPct), [10, 12.5, null]);
  });

  test('cached order JSON round-trip keeps the rate', () async {
    final cached = Order.fromJson((await _fetch(_orderId)).toJson());
    expect(cached.lines.map((l) => l.promoPct), [10, 12.5, null]);
    expect(cached.lines.map((l) => l.net), [920, 700, 1300]);
  });

  test('missing rate in the snapshot stays null (no fabricated %)', () {
    final json = _serverOrder();
    ((json['lines'] as List).first as Map)['ordinaryPromotion'] =
        {'promotionId': 'p', 'name': 'Demo_Demo1', 'discountAmount': 120};
    expect(Order.fromJson(json).lines.first.promoPct, isNull);
  });

  testWidgets('API payload renders "Demo_Demo1 · KM 10%" and savings',
      (tester) async {
    final order = await tester.runAsync(() => _fetch(_orderId));
    await _render(tester, order!);

    expect(find.text('Tiết kiệm 280 VND'), findsOneWidget);
    expect(find.text('Demo_Demo1'), findsOneWidget);
    expect(find.text(' · KM 10%'), findsOneWidget);
    expect(find.text(' · KM 12,5%'), findsOneWidget);
    expect(find.textContaining('23,33'), findsNothing);
    expect(find.textContaining('7,14'), findsNothing);
    Finder row(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
    expect(find.descendant(of: row('Demo_Demo1'), matching: find.text(' · KM 10%')),
        findsOneWidget);
    expect(find.descendant(of: row('Giảm giá theo HSD'),
            matching: find.textContaining('KM ')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('detail read returns the creator id and the cache keeps it', () async {
    final order = await _fetch(_orderId);
    expect(order.createdByUserId, 'sales-a');
    expect(Order.fromJson(order.toJson()).createdByUserId, 'sales-a');
  });
}
