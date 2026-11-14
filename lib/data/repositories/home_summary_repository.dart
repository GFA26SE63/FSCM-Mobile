import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/finance_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';

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
  final counts = await Future.wait(<Future<int>>[
    orders.countByStatus('Quoted'),
    orders.countByStatus('PaymentPending'),
    orders.countByStatus('Delivering'),
  ]);
  final receivables = await ref.watch(receivablesProvider.future);
  int? points;
  try {
    points = (await ref.watch(loyaltyAccountProvider.future)).balance;
  } catch (_) {
    points = null;
  }
  return RetailerTodo.from(
    quotes: counts[0],
    payments: counts[1],
    deliveries: counts[2],
    receivables: receivables,
    now: AppClock.now(),
    points: points,
  );
});
