import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/notification_page.dart';

final notificationsApiProvider = Provider<NotificationsApi>(
    (ref) => NotificationsApi(ref.watch(apiClientProvider)));

/// READ via GraphQL (`notifications`, `notificationBadges`, scoped to the
/// signed-in user by the Backend). Mark-read stays REST.
class NotificationsApi {
  NotificationsApi(this._client) : _graphQl = GraphQlClient(_client);

  final ApiClient _client;
  final GraphQlClient _graphQl;

  /// Backend accepts 1..100 per page; this is the UI page, not a data cap.
  static const int pageSize = 20;

  // Scalar variables: no dependency on the generated input type name.
  static const String _listQuery = r'''
    query Notifications($page: Int!, $pageSize: Int!) {
      notifications(filter: { page: $page, pageSize: $pageSize }) {
        items {
          id type title message isRead createdAt readAt
          relatedEntityType relatedEntityId deepLink
        }
        page pageSize totalCount
      }
    }
  ''';

  static const String _badgeQuery = r'''
    query NotificationBadges { notificationBadges { unreadCount hasUnread } }
  ''';

  Future<NotificationPage> list({int page = 1}) async {
    final data = await _graphQl.query(
      _listQuery,
      operationName: 'Notifications',
      variables: <String, dynamic>{'page': page, 'pageSize': pageSize},
    );
    final result = asMap(data['notifications']);
    return NotificationPage(
      items: asMapList(result['items']).map(AppNotification.fromJson).toList(),
      page: asInt(result['page'], page),
      pageSize: asInt(result['pageSize'], pageSize),
      totalCount: asInt(result['totalCount']),
    );
  }

  Future<int> unreadCount() async {
    final data =
        await _graphQl.query(_badgeQuery, operationName: 'NotificationBadges');
    return asInt(asMap(data['notificationBadges'])['unreadCount']);
  }

  Future<void> markRead(String id) async {
    await _client.patch(Endpoints.notificationRead(id));
  }

  Future<void> markAllRead() async =>
      _client.patch(Endpoints.notificationsReadAll);
}
