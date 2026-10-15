import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/local/local_providers.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/remote/notifications_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    api: ref.watch(notificationsApiProvider),
    syncState: ref.watch(syncStateDaoProvider),
  );
});

/// Server notifications merged with local ones (e.g. "order rejected after
/// sync" created by the sync service). Works offline: local ones only.
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(notificationRepositoryProvider).list();
});

final unreadNotificationsProvider = Provider<int>((ref) {
  final list =
      ref.watch(notificationsProvider).valueOrNull ?? const <AppNotification>[];
  return list.where((n) => n.unread).length;
});

class NotificationRepository {
  NotificationRepository(
      {required NotificationsApi api, required SyncStateDao syncState})
      : _api = api,
        _syncState = syncState;

  final NotificationsApi _api;
  final SyncStateDao _syncState;

  static const int _maxLocal = 50;

  Future<List<AppNotification>> list() async {
    final local = await _readLocal();
    var remote = <AppNotification>[];
    try {
      remote = await _api.list();
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
    }
    return <AppNotification>[...local, ...remote]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isLocal) {
      final list = await _readLocal();
      final i = list.indexWhere((x) => x.id == n.id);
      if (i >= 0) {
        list[i] = list[i].markRead();
        await _writeLocal(list);
      }
      return;
    }
    try {
      await _api.markRead(n.id);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
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
