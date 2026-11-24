import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';

/// Orders per request, first page and every "load more".
const int salesOrdersPageSize = 10;

/// Page size while a status group is assembled by scanning (Backend max 100).
const int _scanPageSize = 100;

/// The status chips of the Sales order list, with their original meaning.
enum SalesOrderGroup {
  all,
  pending,
  inProgress,
  delivered,
  rejected,
  offline;

  bool matches(Order o) {
    switch (this) {
      case SalesOrderGroup.all:
        return true;
      case SalesOrderGroup.pending:
        return o.status == OrderStatus.allocating ||
            o.status == OrderStatus.quoted ||
            o.status == OrderStatus.paymentPending;
      case SalesOrderGroup.inProgress:
        return o.status == OrderStatus.convertedToPo ||
            o.status == OrderStatus.picking ||
            o.status == OrderStatus.issued ||
            o.status == OrderStatus.delivering;
      case SalesOrderGroup.delivered:
        return o.status == OrderStatus.delivered ||
            o.status == OrderStatus.completed;
      case SalesOrderGroup.rejected:
        return o.status.isRejectedOrCancelled;
      case SalesOrderGroup.offline:
        return o.isOffline;
    }
  }

  /// Backend statuses to query, one `orderReads(status:)` stream each. Only
  /// groups whose every server status the Backend filter accepts qualify
  /// (see [OrdersApi.listFilterStatuses]); the legacy `Cancelled` / `Rejected`
  /// exist on queue rows only.
  List<String> get serverStatuses {
    final statuses = OrderStatus.values.where((s) {
      switch (this) {
        case SalesOrderGroup.pending:
          return s == OrderStatus.allocating ||
              s == OrderStatus.quoted ||
              s == OrderStatus.paymentPending;
        case SalesOrderGroup.rejected:
          return s.isRejectedOrCancelled;
        default:
          return false;
      }
    });
    return statuses
        .map((s) => s.code)
        .where(OrdersApi.listFilterStatuses.contains)
        .toList();
  }

  /// Exact server filtering is possible by merging per-status queries.
  bool get filteredOnServer => serverStatuses.isNotEmpty;

  /// The Backend cannot filter these (Picking, Issued, Delivering, Delivered,
  /// Completed are refused by the status filter), so the list is read in full
  /// and filtered here, and shown as incomplete until the last page arrived.
  bool get needsFullScan =>
      this == SalesOrderGroup.inProgress || this == SalesOrderGroup.delivered;
}

/// Provider family key: search text + status chip.
@immutable
class SalesOrdersQuery {
  const SalesOrdersQuery({this.search = '', this.group = SalesOrderGroup.all});

  final String search;
  final SalesOrderGroup group;

  @override
  bool operator ==(Object other) =>
      other is SalesOrdersQuery &&
      other.search == search &&
      other.group == group;

  @override
  int get hashCode => Object.hash(search, group);
}

/// Server orders (offset pages, newest first) merged with the offline queue.
///
/// Only the server rows are paged. The queue is small and local, so it is
/// re-read in full on every refresh; it is never part of the server
/// `totalCount`.
class SalesOrdersState {
  const SalesOrdersState({
    required this.server,
    required this.local,
    required this.search,
    required this.totalCount,
    required this.page,
    required this.hasMore,
    this.group = SalesOrderGroup.all,
    this.offlineOnly = false,
    this.loadingMore = false,
    this.moreError,
  });

  final List<Order> server;
  final List<OfflineOrder> local;

  /// Lower-cased term the server rows were fetched with; also applied to the
  /// local rows, which the server cannot search.
  final String search;
  final SalesOrderGroup group;
  final int totalCount;
  final int page;
  final bool hasMore;
  final bool offlineOnly;
  final bool loadingMore;
  final String? moreError;

  /// A full-scan group is incomplete until its last page has arrived.
  bool get scanning => group.needsFullScan && hasMore && !offlineOnly;

  /// What the list shows: loaded server rows + local rows (existing merge and
  /// de-duplication rules), newest first, restricted to the chip.
  List<Order> get orders {
    final merged =
        mergeServerAndLocalOrders(server, local, offlineOnly: offlineOnly);
    final ids = server.map((o) => o.id).where((id) => id.isNotEmpty).toSet();
    return merged.where((o) {
      // Server rows were fetched for the search; queue rows are matched here.
      final onServer = o.id.isNotEmpty && ids.contains(o.id);
      if (!onServer && search.isNotEmpty) {
        final hay = '${o.displayCode} ${o.retailerName} ${o.retailerCode}'
            .toLowerCase();
        if (!hay.contains(search)) return false;
      }
      return group.matches(o);
    }).toList();
  }

  SalesOrdersState copyWith({
    List<Order>? server,
    int? totalCount,
    int? page,
    bool? hasMore,
    bool loadingMore = false,
    String? moreError,
  }) =>
      SalesOrdersState(
        server: server ?? this.server,
        local: local,
        search: search,
        group: group,
        totalCount: totalCount ?? this.totalCount,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        offlineOnly: offlineOnly,
        loadingMore: loadingMore,
        moreError: moreError,
      );
}

/// The query is the family key: a new search or chip is a new controller, so
/// paging restarts at page 1 and a late answer of the old one cannot reach the
/// new.
final salesOrdersProvider = StateNotifierProvider.autoDispose.family<
    SalesOrdersController,
    AsyncValue<SalesOrdersState>,
    SalesOrdersQuery>((ref, query) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  return SalesOrdersController(
    ref.watch(orderRepositoryProvider),
    search: query.search,
    group: query.group,
    isCurrentUser: () =>
        user != null &&
        user.role == UserRole.sales &&
        ref.read(currentUserProvider)?.id == user.id,
  );
});

/// One Backend status read page by page; several are merged by [SalesOrdersController].
class _StatusStream {
  _StatusStream(this.status);

  final String status;
  int page = 0;
  bool exhausted = false;
  int total = 0;
  final List<Order> buffer = <Order>[];
  final Set<String> seen = <String>{};
}

class SalesOrdersController
    extends StateNotifier<AsyncValue<SalesOrdersState>> {
  SalesOrdersController(
    this._repo, {
    String search = '',
    SalesOrderGroup group = SalesOrderGroup.all,
    required bool Function() isCurrentUser,
  })  : _search = search.trim().toLowerCase(),
        _group = group,
        _isCurrentUser = isCurrentUser,
        super(const AsyncLoading()) {
    unawaited(refresh());
  }

  final OrderRepository _repo;
  final String _search;
  final SalesOrderGroup _group;
  final bool Function() _isCurrentUser;
  int _generation = 0;
  bool _scanRunning = false;
  List<_StatusStream> _streams = <_StatusStream>[];

  bool get _active => mounted && _isCurrentUser();

  String? get _serverSearch => _search.isEmpty ? null : _search;

  bool get _grouped => _group.filteredOnServer;
  bool get _scan => _group.needsFullScan;

  /// Back to page 1. Keeps the shown list while loading; local rows are
  /// re-read, never dropped.
  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_generation;
    _scanRunning = false;
    if (!_active) {
      state = const AsyncError(
          ApiException(
              kind: ApiErrorKind.forbidden,
              message: 'Cần đăng nhập nhân viên bán hàng để xem đơn hàng.'),
          StackTrace.empty);
      return;
    }
    state = const AsyncLoading<SalesOrdersState>().copyWithPrevious(state);
    try {
      final local = await _repo.queueEntries();
      var first = const <Order>[];
      var total = 0;
      var page = 1;
      var hasMore = false;
      var offlineOnly = false;
      try {
        if (_grouped) {
          _streams = <_StatusStream>[
            for (final s in _group.serverStatuses) _StatusStream(s),
          ];
          first = await _takeBatch(salesOrdersPageSize);
          total = _streams.fold(0, (sum, s) => sum + s.total);
          hasMore = _streamsHaveMore;
        } else {
          final result = await _repo.fetchOrdersPage(
              page: 1,
              pageSize: _scan ? _scanPageSize : salesOrdersPageSize,
              search: _serverSearch);
          first = result.items;
          total = result.totalCount;
          page = result.page;
          hasMore = result.hasMore;
        }
      } on ApiException catch (e) {
        if (!e.isNetwork) rethrow;
        offlineOnly = true;
      }
      if (!_active || generation != _generation) return;
      state = AsyncData(SalesOrdersState(
        server: first,
        local: local,
        search: _search,
        group: _group,
        totalCount: total,
        page: page,
        hasMore: hasMore,
        offlineOnly: offlineOnly,
      ));
      if (_scan && hasMore && !offlineOnly) {
        unawaited(_scanRest(generation));
      }
    } catch (error, stack) {
      if (_active && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  /// Next server page (or next merged batch). No-op while another request
  /// runs or after the last page. A failure keeps everything already loaded
  /// and can be retried.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (!_active ||
        current == null ||
        current.loadingMore ||
        _scanRunning ||
        !current.hasMore ||
        current.offlineOnly ||
        state.isLoading) {
      return;
    }
    final generation = _generation;
    if (_scan) {
      await _scanRest(generation); // also the retry after a failed page
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      if (_grouped) {
        final batch = await _takeBatch(salesOrdersPageSize);
        if (!_active || generation != _generation) return;
        state = AsyncData(current.copyWith(
          server: _appendUnique(current.server, batch),
          totalCount: _streams.fold<int>(0, (sum, s) => sum + s.total),
          page: current.page + 1,
          hasMore: _streamsHaveMore,
        ));
        return;
      }
      final next = await _repo.fetchOrdersPage(
          page: current.page + 1,
          pageSize: salesOrdersPageSize,
          search: _serverSearch);
      if (!_active || generation != _generation) return;
      final merged = _appendUnique(current.server, next.items);
      state = AsyncData(current.copyWith(
        server: merged,
        totalCount: next.totalCount,
        page: next.page,
        // A page with nothing new ends paging, so a bad total cannot loop.
        hasMore: next.hasMore && merged.length > current.server.length,
      ));
    } catch (error) {
      if (_active && generation == _generation) {
        state = AsyncData(
            current.copyWith(moreError: ApiException.describe(error)));
      }
    }
  }

  /// Pages 2.. of a full scan, one after the other, until the last page.
  Future<void> _scanRest(int generation) async {
    if (_scanRunning) return;
    _scanRunning = true;
    try {
      while (_active && generation == _generation) {
        final current = state.valueOrNull;
        if (current == null || !current.hasMore) break;
        state = AsyncData(current.copyWith(loadingMore: true));
        try {
          final next = await _repo.fetchOrdersPage(
              page: current.page + 1,
              pageSize: _scanPageSize,
              search: _serverSearch);
          if (!_active || generation != _generation) return;
          final merged = _appendUnique(current.server, next.items);
          state = AsyncData(current.copyWith(
            server: merged,
            totalCount: next.totalCount,
            page: next.page,
            hasMore: next.hasMore && merged.length > current.server.length,
          ));
        } catch (error) {
          if (_active && generation == _generation) {
            state = AsyncData(
                current.copyWith(moreError: ApiException.describe(error)));
          }
          return; // the retry button continues from this page
        }
      }
    } finally {
      _scanRunning = false;
    }
  }

  // Stable identity: the server id; code if an id were ever missing.
  static String _key(Order o) => o.id.isNotEmpty ? o.id : o.code;

  static List<Order> _appendUnique(List<Order> current, List<Order> next) {
    final byKey = <String, Order>{for (final o in current) _key(o): o};
    for (final o in next) {
      byKey.putIfAbsent(_key(o), () => o);
    }
    return byKey.values.toList();
  }

  // ---- merged per-status streams (pending / rejected chips) -------------

  bool get _streamsHaveMore =>
      _streams.any((s) => s.buffer.isNotEmpty || !s.exhausted);

  /// Server order: newest first, ties by code descending (what the Backend
  /// uses within a single status).
  static int _newestFirst(Order a, Order b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.code.compareTo(a.code);
  }

  Future<void> _fetchMore(_StatusStream s) async {
    final page = s.page + 1; // advanced only once the page arrived
    final result = await _repo.fetchOrdersPage(
        page: page,
        pageSize: salesOrdersPageSize,
        search: _serverSearch,
        status: s.status);
    s.page = page;
    final fresh = result.items.where((o) => s.seen.add(_key(o))).toList();
    s.buffer.addAll(fresh);
    s.total = result.totalCount;
    // Nothing new, or the last page: this status has nothing more to give.
    if (fresh.isEmpty || !result.hasMore) s.exhausted = true;
  }

  /// Takes the next [count] orders across all statuses in global order. A
  /// status whose buffer ran dry is refilled before anything newer-than-its-
  /// next-row is taken, so the merge is exact. On failure nothing is lost.
  Future<List<Order>> _takeBatch(int count) async {
    final taken = <Order>[];
    try {
      while (taken.length < count) {
        final dry =
            _streams.where((s) => s.buffer.isEmpty && !s.exhausted).toList();
        if (dry.isNotEmpty) {
          await Future.wait(dry.map(_fetchMore));
          continue;
        }
        _StatusStream? best;
        for (final s in _streams) {
          if (s.buffer.isEmpty) continue;
          if (best == null ||
              _newestFirst(s.buffer.first, best.buffer.first) < 0) {
            best = s;
          }
        }
        if (best == null) break;
        taken.add(best.buffer.removeAt(0));
      }
    } catch (_) {
      for (final o in taken.reversed) {
        _streams
            .firstWhere((s) => s.status == o.status.code)
            .buffer
            .insert(0, o);
      }
      rethrow;
    }
    return taken;
  }
}
