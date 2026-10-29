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
import 'package:fscm_mobile/data/models/picking.dart';
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
    this.email = '',
    this.password = 'Fscm2026',
    this.isActive = true,
    this.mustChangePassword = false,
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
  final String email;
  final String phone;
  final UserRole role;
  final String password;
  final bool isActive;
  final bool mustChangePassword;
  final String? areaCode;
  final String? areaName;
  final String? salesGroup;
  final String? warehouseCode;
  final String? warehouseName;
  final String? retailerCode;
  final String? retailerName;
  final String? retailerAddress;

  UserScope get scope => UserScope(
        warehouseIds:
            warehouseCode != null ? <String>[warehouseCode!] : const <String>[],
        salesGroupIds:
            salesGroup != null ? <String>[salesGroup!] : const <String>[],
        regionIds: areaCode != null ? <String>[areaCode!] : const <String>[],
        retailerIds:
            retailerCode != null ? <String>[retailerCode!] : const <String>[],
      );

  UserScopeLabels get scopeLabels => UserScopeLabels(
        warehouses: warehouseCode != null
            ? <ScopeLabel>[
                ScopeLabel(
                  id: 'wh-$warehouseCode',
                  code: warehouseCode!,
                  name: warehouseName ?? 'Kho $warehouseCode',
                )
              ]
            : const <ScopeLabel>[],
        salesGroups: salesGroup != null
            ? <ScopeLabel>[
                ScopeLabel(
                  id: 'grp-$salesGroup',
                  code: salesGroup!,
                  name: 'Nhóm $salesGroup',
                )
              ]
            : const <ScopeLabel>[],
        regions: areaCode != null
            ? <ScopeLabel>[
                ScopeLabel(
                  id: 'reg-$areaCode',
                  code: areaCode!,
                  name: areaName ?? 'Khu vực $areaCode',
                )
              ]
            : const <ScopeLabel>[],
        retailers: retailerCode != null
            ? <ScopeLabel>[
                ScopeLabel(
                  id: 'rt-$retailerCode',
                  code: retailerCode!,
                  name: retailerName ?? 'Điểm bán $retailerCode',
                )
              ]
            : const <ScopeLabel>[],
      );

  AppUser toAppUser() => AppUser(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        role: role,
        isActive: isActive,
        mustChangePassword: mustChangePassword,
        scope: scope,
        scopeLabels: scopeLabels,
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
  String get refreshToken => 'refresh.${role.code}.$id';
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

  final Map<String, PickingList> pickings = <String, PickingList>{};
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

  MockUser? userByRefreshToken(String? refreshToken) {
    if (refreshToken == null || refreshToken.isEmpty) return null;
    for (final u in users) {
      if (u.refreshToken == refreshToken) return u;
    }
    return null;
  }

  MockUser? userByIdentifier(String identifier) {
    final trimmed = identifier.trim().toLowerCase();
    final compact = identifier.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.isEmpty) return null;
    for (final u in users) {
      if (u.email.isNotEmpty && u.email.toLowerCase() == trimmed) return u;
      if (u.phone.isNotEmpty && u.phone == compact) return u;
    }
    return null;
  }

  MockUser? userByLogin(
    String identifier,
    String password, {
    String? fallbackPhone,
  }) {
    final u = userByIdentifier(identifier) ??
        (fallbackPhone != null && fallbackPhone.isNotEmpty
            ? userByIdentifier(fallbackPhone)
            : null);
    if (u == null) return null;
    final acceptedPasswords = <String>{
      u.password,
      'Fscm2026',
      'Fscm@2026',
      '12345678',
    };
    if (acceptedPasswords.contains(password)) return u;
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
