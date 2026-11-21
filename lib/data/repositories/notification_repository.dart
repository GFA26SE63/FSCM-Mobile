import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/notification_page.dart';
import 'package:fscm_mobile/data/remote/notifications_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    api: ref.watch(notificationsApiProvider),
    syncState: ref.watch(syncStateDaoProvider),
  );
});

/// Server notifications (paged) merged with local ones (e.g. "order rejected
/// after sync" created by the sync service). Works offline: local ones only.
final notificationsProvider = StateNotifierProvider<NotificationsController,
    AsyncValue<NotificationsState>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return NotificationsController(
    ref.watch(notificationRepositoryProvider),
    onServerChanged: () => ref.invalidate(notificationBadgeProvider),
  );
});

/// Server-side unread count (`notificationBadges`); 0 while offline.
final notificationBadgeProvider = FutureProvider<int>((ref) async {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  try {
    return await ref.watch(notificationRepositoryProvider).unreadCount();
  } on ApiException catch (e) {
    if (e.isNetwork) return 0;
    rethrow;
  }
});

final unreadNotificationsProvider = Provider<int>((ref) {
  final server = ref.watch(notificationBadgeProvider).valueOrNull ?? 0;
  final local = ref.watch(notificationsProvider).valueOrNull?.local ??
      const <AppNotification>[];
  return server + local.where((n) => n.unread).length;
});

class NotificationsState {
  const NotificationsState({
    required this.local,
    required this.server,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.moreError,
  });

  final List<AppNotification> local;
  final List<AppNotification> server;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? moreError;

  /// Newest first, as before.
  List<AppNotification> get items => <AppNotification>[...local, ...server]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  NotificationsState copyWith({
    List<AppNotification>? local,
    List<AppNotification>? server,
    int? page,
    bool? hasMore,
    bool loadingMore = false,
    String? moreError,
  }) =>
      NotificationsState(
        local: local ?? this.local,
        server: server ?? this.server,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore,
        moreError: moreError,
      );
}

class NotificationsController
    extends StateNotifier<AsyncValue<NotificationsState>> {
  NotificationsController(this._repo, {required this.onServerChanged})
      : super(const AsyncLoading()) {
    unawaited(refresh());
  }

  final NotificationRepository _repo;
  final void Function() onServerChanged;
  int _generation = 0;

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_generation;
    // Keep showing the current list while reloading.
    state = const AsyncLoading<NotificationsState>().copyWithPrevious(state);
    try {
      final local = await _repo.readLocal();
      var server = const NotificationPage(
          items: <AppNotification>[], page: 1, pageSize: 1, totalCount: 0);
      try {
        server = await _repo.fetchPage(1);
      } on ApiException catch (e) {
        if (!e.isNetwork) rethrow;
      }
      if (!mounted || generation != _generation) return;
      state = AsyncData(NotificationsState(
          local: local,
          server: server.items,
          page: server.page,
          hasMore: server.hasMore));
    } catch (error, stack) {
      if (mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (!mounted ||
        current == null ||
        current.loadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _repo.fetchPage(current.page + 1);
      if (!mounted || generation != _generation) return;
      final byId = <String, AppNotification>{
        for (final n in current.server) n.id: n,
      };
      for (final n in next.items) {
        byId[n.id] = n;
      }
      state = AsyncData(current.copyWith(
          server: byId.values.toList(),
          page: next.page,
          // A page that adds nothing new ends paging (no loop on a bad total).
          hasMore: next.hasMore && byId.length > current.server.length));
    } catch (error) {
      if (mounted && generation == _generation) {
        state = AsyncData(
            current.copyWith(moreError: ApiException.describe(error)));
      }
    }
  }

  Future<void> markRead(AppNotification n) async {
    final applied = await _repo.markRead(n);
    if (!applied || !mounted) return;
    final current = state.valueOrNull;
    if (current != null) {
      AppNotification swap(AppNotification x) =>
          x.id == n.id ? x.markRead() : x;
      state = AsyncData(current.copyWith(
          local: current.local.map(swap).toList(),
          server: current.server.map(swap).toList()));
    }
    if (!n.isLocal) onServerChanged();
  }

  Future<void> markAllRead() async {
    final applied = await _repo.markAllRead();
    if (!mounted) return;
    final current = state.valueOrNull;
    if (current != null && applied) {
      state = AsyncData(current.copyWith(
          local: current.local.map((x) => x.markRead()).toList(),
          server: current.server.map((x) => x.markRead()).toList()));
    }
    onServerChanged();
  }
}

class NotificationRepository {
  NotificationRepository(
      {required NotificationsApi api, required SyncStateDao syncState})
      : _api = api,
        _syncState = syncState;

  final NotificationsApi _api;
  final SyncStateDao _syncState;

  static const int _maxLocal = 50;

  Future<List<AppNotification>> readLocal() => _readLocal();

  Future<NotificationPage> fetchPage(int page) => _api.list(page: page);

  Future<int> unreadCount() => _api.unreadCount();

  /// True when the change reached its store (device or server). A network
  /// failure is tolerated as before, but reported so the UI does not show a
  /// notification as read while the server still has it unread.
  Future<bool> markRead(AppNotification n) async {
    if (n.isLocal) {
      final list = await _readLocal();
      final i = list.indexWhere((x) => x.id == n.id);
      if (i >= 0) {
        list[i] = list[i].markRead();
        await _writeLocal(list);
      }
      return true;
    }
    try {
      await _api.markRead(n.id);
      return true;
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      return false;
    }
  }

  Future<bool> markAllRead() async {
    final local = await _readLocal();
    if (local.any((item) => item.unread)) {
      await _writeLocal(local.map((item) => item.markRead()).toList());
    }
    try {
      await _api.markAllRead();
      return true;
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      return false;
    }
  }

  /// Creates an in-app notification stored on the device.
  Future<void> addLocal(String text,
      {String orderCode = '', String kind = 'order'}) async {
    final list = await _readLocal();
    final now = AppClock.now();
    list.insert(
      0,
      AppNotification(
        id: 'local-${now.microsecondsSinceEpoch}',
        text: text,
        createdAt: now,
        orderCode: orderCode,
        kind: kind,
        isLocal: true,
      ),
    );
    await _writeLocal(list.take(_maxLocal).toList());
  }

  Future<List<AppNotification>> _readLocal() async {
    final raw = await _syncState.get(SyncStateDao.keyLocalNotifications);
    if (raw == null || raw.isEmpty) return <AppNotification>[];
    try {
      return asMapList(jsonDecode(raw)).map(AppNotification.fromJson).toList();
    } on FormatException {
      return <AppNotification>[];
    }
  }

  Future<void> _writeLocal(List<AppNotification> list) => _syncState.set(
        SyncStateDao.keyLocalNotifications,
        jsonEncode(list.map((n) => n.toJson()).toList()),
      );
}
