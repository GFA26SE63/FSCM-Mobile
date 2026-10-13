import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_registration.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';
import 'package:fscm_mobile/data/pricing/promotion_calculator.dart';

/// `/sync/snapshot`, `/retailers`, `/retailer-registrations`, `/products`,
/// `/promotions`, `/pricing/quote`.
class MockCatalogHandler extends MockHandler {
  MockCatalogHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;
    if (user == null) return null;

    if (r.matches('GET', '/sync/snapshot')) return _snapshot(user);

    if (r.matches('GET', '/retailers')) {
      final search = r.queryStr('search').toLowerCase();
      final list = store.retailers.where((x) {
        if (search.isEmpty) return true;
        return x.name.toLowerCase().contains(search) || x.code.contains(search);
      });
      return MockReply.page(list.map((x) => x.toJson()).toList());
    }
    if (r.matches('GET', '/retailers/*')) {
      final x = store.retailer(r.segments[1]);
      return x == null
          ? MockReply.notFound('điểm bán ${r.segments[1]}')
          : MockReply.ok(x.toJson());
    }

    if (r.matches('GET', '/retailer-registrations')) {
      return MockReply.page(store.registrations.map(_regJson).toList());
    }
    if (r.matches('POST', '/retailer-registrations')) return _declare(user, r);

    if (r.matches('GET', '/products')) {
      return MockReply.page(store.products.map((p) => p.toJson()).toList());
    }
    if (r.matches('GET', '/promotions')) {
      return MockReply.page(
          store.snapshotPromotions().map((p) => p.toJson()).toList());
    }
    if (r.matches('POST', '/pricing/quote')) {
      final lines = mapList(r.body['lines'], CartLine.fromJson);
      final quote = PromotionCalculator.quote(
        lines: lines,
        retailerCode: asStr(r.body['retailerCode']),
        promotions: store.serverPromotions(),
        products: store.productMap,
        prices: store.prices,
        now: store.now(),
      );
      return MockReply.ok(quote.toJson());
    }
    return null;
  }

  ApiResponse _snapshot(MockUser user) {
    final snapshot = SyncSnapshot(
      serverTime: store.now(),
      retailers: store.retailers,
      products: store.products,
      prices: store.products
          .map((Product p) => PriceEntry(sku: p.sku, price: p.basePrice))
          .toList(),
      promotions: store.snapshotPromotions(),
      stock: store.stock.entries
          .map((e) => StockEntry(sku: e.key, available: e.value))
          .toList(),
    );
    // After the first download Admin pauses KM-003 (prototype scenario).
    if (!store.snapshotServed) {
      store.snapshotServed = true;
      if (store.pauseKm003AfterFirstSnapshot) {
        store.pausedPromoIds.add('KM-003');
      }
    }
    return MockReply.ok(snapshot.toJson());
  }

  ApiResponse _declare(MockUser user, MockRequest r) {
    final name = asStr(r.body['name']).trim();
    final address = asStr(r.body['address']).trim();
    if (name.isEmpty || address.isEmpty) {
      return MockReply.invalid('Vui lòng nhập tên và địa chỉ điểm bán.');
    }
    final dup = store.retailers
        .where((x) => x.address.toLowerCase() == address.toLowerCase());
    if (dup.isNotEmpty) {
      return MockReply.conflict(
          'Trùng địa chỉ với điểm bán ${dup.first.code} (${dup.first.name}).');
    }
    final code =
        'KB-${(store.nextRegistrationNo++).toString().padLeft(4, '0')}';
    final reg = RetailerRegistration(
      code: code,
      name: name,
      address: address,
      contactName: asStr(r.body['contactName']),
      phone: asStr(r.body['phone']),
      areaName: user.areaName ?? '',
      status: RegistrationStatus.waiting,
      potential: RetailerPotential.fromJson(asMap(r.body['potential'])),
      timeline: <TimelineEntry>[
        TimelineEntry(time: store.now(), label: 'Bạn gửi khai báo')
      ],
    );
    store.registrations.insert(0, reg);
    return MockReply.created(_regJson(reg));
  }

  Map<String, dynamic> _regJson(RetailerRegistration x) => <String, dynamic>{
        'code': x.code,
        'name': x.name,
        'address': x.address,
        'contactName': x.contactName,
        'phone': x.phone,
        'areaName': x.areaName,
        'status': x.status.code,
        'retailerCode': x.retailerCode,
        'reason': x.reason,
        'potential': x.potential.toJson(),
        'timeline': x.timeline.map((t) => t.toJson()).toList(),
      };
}
