import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

final notificationsApiProvider = Provider<NotificationsApi>(
    (ref) => NotificationsApi(ref.watch(apiClientProvider)));

class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  Future<List<AppNotification>> list() async {
    final notifications = <AppNotification>[];
    for (var page = 1; ; page++) {
      final data = await _client.get(
        Endpoints.notifications,
        query: {'page': page},
      );
      final items = unwrapItems(data);
      notifications.addAll(items.map(AppNotification.fromJson));
      if (items.isEmpty ||
          notifications.length >= asInt(asMap(data)['totalCount'])) {
        return notifications;
      }
    }
  }

  Future<void> markRead(String id) async {
    await _client.patch(Endpoints.notificationRead(id));
  }

  Future<void> markAllRead() async =>
      _client.patch(Endpoints.notificationsReadAll);
}
