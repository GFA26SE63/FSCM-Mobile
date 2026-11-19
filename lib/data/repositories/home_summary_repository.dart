import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';

/// Today's warehouse tiles, read from the same `/dashboard` endpoint as the
/// Portal so the numbers on both screens agree.
class WarehouseDashboard {
  WarehouseDashboard({required this.cards, required this.loadedAt});

  factory WarehouseDashboard.fromJson(Map<String, dynamic> j, DateTime at) =>
      WarehouseDashboard(
        cards: <String, num>{
          for (final card in asMapList(j['cards']))
            asStr(card['key']): (card['value'] as num?) ?? 0,
        },
        loadedAt: at,
      );

  final Map<String, num> cards;

  /// When the device received the figures (shown as "Cập nhật ...").
  final DateTime loadedAt;

  int count(String key) => (cards[key] ?? 0).round();
}

final warehouseDashboardProvider =
    FutureProvider.autoDispose<WarehouseDashboard>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  if (user?.role != UserRole.warehouseKeeper) {
    return WarehouseDashboard(cards: const {}, loadedAt: AppClock.now());
  }
  final today = PerformancePeriod.forKey('today', AppClock.now());
  final data = await ref
      .watch(apiClientProvider)
      .get(Endpoints.dashboard, query: today.query);
  return WarehouseDashboard.fromJson(asMap(data), AppClock.now());
});

/// What a retailer has to act on, shown at the top of "Đơn hàng".
class RetailerTodo {
  const RetailerTodo({
    required this.quotesToConfirm,
    required this.paymentsPending,
    required this.deliveriesToReceive,
    required this.overdueCount,
    required this.overdueAmount,
    required this.dueSoonCount,
    required this.dueSoonAmount,
    this.loyaltyPoints,
  });

  final int quotesToConfirm;
  final int paymentsPending;
  final int deliveriesToReceive;
  final int overdueCount;
  final int overdueAmount;

  /// Open credit due within the next 7 days.
  final int dueSoonCount;
  final int dueSoonAmount;

  /// Null when the loyalty card could not be read; the rest still shows.
  final int? loyaltyPoints;

  bool get hasAction =>
      quotesToConfirm + paymentsPending + deliveriesToReceive + overdueCount >
      0;

  static RetailerTodo from({
    required int quotes,
    required int payments,
    required int deliveries,
    required List<Receivable> receivables,
    required DateTime now,
    int? points,
  }) {
    final open = receivables
        .where((r) => !r.isPaid && !r.isCancelled && r.outstandingAmount > 0)
        .toList();
    final overdue = open.where((r) => r.isOverdue).toList();
    final today = DateTime(now.year, now.month, now.day);
    final soon = open.where((r) {
      final due = r.dueDate;
      if (r.isOverdue || due == null) return false;
      final d = DateTime(due.year, due.month, due.day);
      return !d.isBefore(today) && d.difference(today).inDays <= 7;
    }).toList();
    int sum(List<Receivable> rows) =>
        rows.fold<int>(0, (s, r) => s + r.outstandingAmount);
    return RetailerTodo(
      quotesToConfirm: quotes,
      paymentsPending: payments,
      deliveriesToReceive: deliveries,
      overdueCount: overdue.length,
      overdueAmount: sum(overdue),
      dueSoonCount: soon.length,
      dueSoonAmount: sum(soon),
      loyaltyPoints: points,
    );
  }
}

final retailerTodoProvider =
    FutureProvider.autoDispose<RetailerTodo>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  if (user?.role != UserRole.retailer) {
    return RetailerTodo.from(
        quotes: 0,
        payments: 0,
        deliveries: 0,
        receivables: const <Receivable>[],
        now: AppClock.now());
  }
  final orders = ref.watch(ordersApiProvider);
  final counts = await orders
      .countsByStatus(<String>['Quoted', 'PaymentPending', 'Delivering']);
  final receivables = await ref.watch(receivablesProvider.future);
  int? points;
  try {
    points = (await ref.watch(loyaltyAccountProvider.future)).balance;
  } catch (_) {
    points = null;
  }
  return RetailerTodo.from(
    quotes: counts['Quoted']!,
    payments: counts['PaymentPending']!,
    deliveries: counts['Delivering']!,
    receivables: receivables,
    now: AppClock.now(),
    points: points,
  );
});

/// Sales home tiles. Server figures are exact: status counts and today's
/// created / rejected counts are server aggregates (`totalCount`), never taken
/// from a partial list.
class SalesOrderStats {
  const SalesOrderStats({
    this.createdToday = 0,
    this.waiting = 0,
    this.rejectedToday = 0,
    this.delivering = 0,
  });

  final int createdToday;
  final int waiting;
  final int rejectedToday;
  final int delivering;
}

/// Safety stop of the fallback scan; reaching it is an error, not a total.
const int _todayScanMaxPages = 2000;

/// Today's (Vietnam day) own orders and how many of them were rejected or
/// cancelled, as exact counts.
///
/// 1. Server aggregate on `entities.salesOrders` (own orders, `createdAt` in
///    the Vietnam day, optional status set): one request each.
/// 2. If that query is refused, scan `orderReads` newest first until the first
///    order older than today and count. The Backend sorts by `ServerReceivedAt`
///    and an order is created with `CreatedAt == ServerReceivedAt`, so the
///    first older order ends the day. No page cap: the total stays exact.
Future<({int created, int rejected})> salesTodayCounts({
  required OrdersApi api,
  required OrderRepository repository,
  required String ownerUserId,
  required DateTime now,
}) async {
  // Vietnam midnight as an instant (UTC+7, no DST) and the next one.
  final from = AppDates.vietnamDay(now).subtract(const Duration(hours: 7));
  final to = from.add(const Duration(days: 1));
  final rejectedCodes = OrderStatus.values
      .where((s) => s.isRejectedOrCancelled)
      .map((s) => s.code)
      .toList();
  try {
    final results = await Future.wait(<Future<int>>[
      api.countOwnOrdersCreated(ownerUserId: ownerUserId, from: from, to: to),
      api.countOwnOrdersCreated(
          ownerUserId: ownerUserId,
          from: from,
          to: to,
          statuses: rejectedCodes),
    ]);
    return (created: results[0], rejected: results[1]);
  } on ApiException catch (e) {
    // Network and authentication failures are not a missing capability.
    if (e.isNetwork ||
        e.kind == ApiErrorKind.unauthorized ||
        e.kind == ApiErrorKind.forbidden) {
      rethrow;
    }
  }

  var created = 0;
  var rejected = 0;
  for (var page = 1; page <= _todayScanMaxPages; page++) {
    final result = await repository.fetchOrdersPage(page: page, pageSize: 100);
    var reachedOlder = false;
    for (final order in result.items) {
      if (!AppDates.isSameVietnamDay(order.createdAt, now)) {
        reachedOlder = true;
        break;
      }
      created++;
      if (order.status.isRejectedOrCancelled) rejected++;
    }
    if (reachedOlder || result.items.isEmpty || !result.hasMore) {
      return (created: created, rejected: rejected);
    }
  }
  throw const ApiException(
      kind: ApiErrorKind.server,
      message: 'Không thể đếm đầy đủ đơn hàng hôm nay.');
}

final salesOrderStatsProvider =
    FutureProvider.autoDispose<SalesOrderStats>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.sales) {
    return const SalesOrderStats();
  }

  final repository = ref.watch(orderRepositoryProvider);
  final api = ref.watch(ordersApiProvider);
  final now = AppClock.now();

  // Queue rows that are not on the server yet (unsent or rejected). They are
  // counted on their own and never mixed into a server total; synced rows are
  // already counted by the server.
  final local = (await repository.queueEntries())
      .where((entry) => entry.status != SyncStatus.synced)
      .map(orderFromOffline)
      .toList();
  var created =
      local.where((o) => AppDates.isSameVietnamDay(o.createdAt, now)).length;
  var rejected = local
      .where((o) =>
          o.status.isRejectedOrCancelled &&
          AppDates.isSameVietnamDay(o.createdAt, now))
      .length;
  var waiting = local.where((o) => o.status == OrderStatus.allocating).length;
  var delivering = 0;

  try {
    final counts = await api.countsByStatus(
        <String>['Allocating', 'Quoted', 'PaymentPending', 'Delivering'],
        ownerUserId: user.id);
    waiting +=
        counts['Allocating']! + counts['Quoted']! + counts['PaymentPending']!;
    delivering = counts['Delivering']!;

    final today = await salesTodayCounts(
        api: api, repository: repository, ownerUserId: user.id, now: now);
    created += today.created;
    rejected += today.rejected;
  } on ApiException catch (e) {
    if (!e.isNetwork) rethrow; // offline: local rows only, as before
  }
  return SalesOrderStats(
    createdToday: created,
    waiting: waiting,
    rejectedToday: rejected,
    delivering: delivering,
  );
});
