import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/mock/mock_seed.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_registration.dart';
import 'package:fscm_mobile/data/models/transfer.dart';

/// Demo account known to the mock backend.
class MockUser {
  const MockUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.password = 'Fscm2026',
    this.areaCode,
    this.areaName,
    this.salesGroup,
    this.warehouseCode,
    this.warehouseName,
    this.retailerCode,
    this.retailerName,
    this.retailerAddress,
  });

  final String id;
  final String fullName;
  final String phone;
  final UserRole role;
  final String password;
  final String? areaCode;
  final String? areaName;
  final String? salesGroup;
  final String? warehouseCode;
  final String? warehouseName;
  final String? retailerCode;
  final String? retailerName;
  final String? retailerAddress;

  AppUser toAppUser() => AppUser(
        id: id,
        fullName: fullName,
        phone: phone,
        role: role,
        areaCode: areaCode,
        areaName: areaName,
        salesGroup: salesGroup,
        warehouseCode: warehouseCode,
        warehouseName: warehouseName,
        retailerCode: retailerCode,
        retailerName: retailerName,
        retailerAddress: retailerAddress,
      );

  String get token => 'mock.${role.code}.$id';
}

/// Points state of one retailer in the mock Loyalty module. Pending and
/// held points are derived from the ledger.
class MockLoyalty {
  MockLoyalty({required this.balance, List<PointLedgerEntry>? ledger})
      : ledger = ledger ?? <PointLedgerEntry>[];

  /// Available points.
  int balance;
  final List<PointLedgerEntry> ledger;

  int get pending => ledger
      .where((e) => e.kind == PointKind.pending)
      .fold<int>(0, (s, e) => s + e.points);

  int get held => ledger
      .where((e) => e.kind == PointKind.held)
      .fold<int>(0, (s, e) => s - e.points);
}

/// Revenue row used to build KPI and rankings (Performance read model).
class MockSale {
  const MockSale({
    required this.orderCode,
    required this.retailerCode,
    required this.createdAt,
    required this.revenue,
    required this.afterPromo,
  });

  final String orderCode;
  final String retailerCode;
  final DateTime createdAt;
  final int revenue;
  final int afterPromo;
}

class MockPerson {
  const MockPerson(this.name, this.group, this.revenue, this.afterPromo);
  final String name;
  final String group;
  final int revenue;
  final int afterPromo;
}

/// In-memory state of the whole mock backend. Seeded from the approved
/// prototypes (Main / Retailer / Warehouse .dc.html): 27/09/2026 10:12.
class MockStore {
  MockStore() {
    MockSeed.fill(this);
  }

  final List<MockUser> users = <MockUser>[];
  final List<Product> products = <Product>[];
  final List<Retailer> retailers = <Retailer>[];
  final List<Promotion> promotions = <Promotion>[];

  /// Promotions paused by Admin on the server after the first snapshot was
  /// served (demonstrates "KM thay đổi khi đồng bộ").
  final Set<String> pausedPromoIds = <String>{};
  bool pauseKm003AfterFirstSnapshot = true;
  bool snapshotServed = false;

  /// Another Sales' order reserves stock before the first offline sync
  /// arrives (demonstrates "server result is final").
  bool simulateConflict = true;
  bool conflictApplied = false;

  final Map<String, int> stock = <String, int>{};
  final List<Order> orders = <Order>[];
  int nextOrderNo = 1031;
  final Map<String, OrderSyncResult> processedSync =
      <String, OrderSyncResult>{};

  /// Run picking sheets and order shipments are held as the JSON the real API
  /// would send, keyed by picking code and by shipment id. Holding them as
  /// parsed models let the mock quietly answer in a shape the server does not
  /// use; as JSON, every read goes through the same parsing as production.
  final Map<String, Map<String, dynamic>> pickingSheets =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> shipments =
      <String, Map<String, dynamic>>{};

  /// Idempotency keys of pick scans already applied, so a repeat returns the
  /// sheet unchanged the way the server does.
  final Set<String> scanKeys = <String>{};

  final Map<String, LabelInfo> labels = <String, LabelInfo>{};
  int nextLabelNo = 250;
  final List<Transfer> transfers = <Transfer>[];

  final List<Receivable> receivables = <Receivable>[];
  final Map<String, MockLoyalty> loyalty = <String, MockLoyalty>{};
  final List<Gift> gifts = <Gift>[];
  final List<GiftRedemption> redemptions = <GiftRedemption>[];
  int nextRedemptionNo = 2;
  final List<Complaint> complaints = <Complaint>[];
  int nextComplaintNo = 1;

  /// key = role code + id, see [notificationKey].
  final Map<String, List<AppNotification>> notifications =
      <String, List<AppNotification>>{};
  final List<RetailerRegistration> registrations = <RetailerRegistration>[];
  int nextRegistrationNo = 13;

  final List<MockSale> sales = <MockSale>[];
  final List<MockPerson> people = <MockPerson>[];
  final List<List<Object>> topProducts = <List<Object>>[];
  int salesTarget = 200000000;

  // -------------------------------------------------------------- helpers

  DateTime now() => AppClock.now();

  MockUser? userByToken(String? token) {
    if (token == null) return null;
    for (final u in users) {
      if (u.token == token) return u;
    }
    return null;
  }

  MockUser? userByLogin(String phone, String password) {
    final p = phone.replaceAll(RegExp(r'\s+'), '');
    for (final u in users) {
      if (u.phone == p && u.password == password) return u;
    }
    return null;
  }

  Map<String, Product> get productMap =>
      <String, Product>{for (final p in products) p.sku: p};

  Map<String, int> get prices =>
      <String, int>{for (final p in products) p.sku: p.basePrice};

  Retailer? retailer(String code) {
    for (final r in retailers) {
      if (r.code == code) return r;
    }
    return null;
  }

  Order? orderByCode(String code) {
    for (final o in orders) {
      if (o.code == code) return o;
    }
    return null;
  }

  void replaceOrder(Order updated) {
    final i = orders.indexWhere((o) => o.code == updated.code);
    if (i >= 0) orders[i] = updated;
  }

  /// Promotions as the server currently sees them.
  List<Promotion> serverPromotions() =>
      promotions.where((p) => !pausedPromoIds.contains(p.id)).toList();

  /// Promotions as sent to the device (paused ones flagged inactive).
  List<Promotion> snapshotPromotions() => promotions
      .map((p) => pausedPromoIds.contains(p.id)
          ? Promotion(
              id: p.id,
              name: p.name,
              type: p.type,
              validFrom: p.validFrom,
              validTo: p.validTo,
              active: false,
              retailerCodes: p.retailerCodes,
              rules: p.rules,
              groupSkus: p.groupSkus,
              groupMinQty: p.groupMinQty,
              groupPct: p.groupPct,
            )
          : p)
      .toList();

  String newOrderCode() {
    final code = 'DH-${(nextOrderNo++).toString().padLeft(6, '0')}';
    return code;
  }

  String newLabelCode() => 'TEM-${(nextLabelNo++).toString().padLeft(6, '0')}';

  String newDocCode(String prefix, int seq) {
    final d = now();
    final yy = (d.year % 100).toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$prefix-$yy$mm$dd-${seq.toString().padLeft(2, '0')}';
  }

  static String notificationKey(MockUser u) => '${u.role.code}.${u.id}';

  List<AppNotification> notificationsFor(MockUser u) =>
      notifications.putIfAbsent(notificationKey(u), () => <AppNotification>[]);

  void notify(MockUser u, String text,
      {String orderCode = '', String kind = ''}) {
    final list = notificationsFor(u);
    list.insert(
      0,
      AppNotification(
        id: 'N${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        createdAt: now(),
        orderCode: orderCode,
        kind: kind,
      ),
    );
  }

  MockUser? retailerUser(String retailerCode) {
    for (final u in users) {
      if (u.retailerCode == retailerCode) return u;
    }
    return null;
  }

  static String fmtTime(DateTime d) => AppDates.timeDay(d);
}
