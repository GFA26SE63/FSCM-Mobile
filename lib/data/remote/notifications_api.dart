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
    final data = await _client.get(Endpoints.notifications);
    return unwrapItems(data).map(AppNotification.fromJson).toList();
  }

  Future<void> markRead(String id) async {
    await _client.post(Endpoints.notificationRead(id));
  }
}
