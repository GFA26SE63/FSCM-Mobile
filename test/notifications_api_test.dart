import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/local/daos/sync_state_dao.dart';
import 'package:fscm_mobile/data/remote/notifications_api.dart';
import 'package:fscm_mobile/data/repositories/notification_repository.dart';

void main() {
  test('reads pages and badge via GraphQL; mark-read stays PATCH', () async {
    final transport = _NotificationTransport(totalCount: 3);
    final api = NotificationsApi(
      ApiClient(transport: transport, tokenReader: () => null),
    );

    final first = await api.list();
    expect(first.items.map((item) => item.id), ['n-1', 'n-2']);
    expect(first.items.first.unread, isTrue);
    expect(first.items.first.deepLink, '/orders/o-1');
    expect(first.hasMore, isTrue);

    final second = await api.list(page: 2);
    expect(second.items.map((item) => item.id), ['n-3']);
    expect(second.hasMore, isFalse);

    expect(await api.unreadCount(), 7);

    // User scope comes from the token on the Backend: no user id is sent.
    for (final request in transport.graphQl) {
      expect(request.path, Env.effectiveGraphQlEndpoint);
      expect(jsonEncode(request.body), isNot(contains('userId')));
    }
    expect(transport.graphQl.first.body.toString(), contains('notifications'));

    await api.markRead('n-1');
    await api.markAllRead();
    expect(transport.rest.map((request) => request.toString()), [
      'PATCH /notifications/n-1/read',
      'PATCH /notifications/read-all',
    ]);
    expect(transport.rest.any((request) => request.method == 'GET'), isFalse);
  });

  group('controller', () {
    late _NotificationTransport transport;
    late _MemorySyncState syncState;
    late NotificationsController controller;
    var badgeRefreshes = 0;
    setUp(() => badgeRefreshes = 0);

    NotificationsController build(int total) {
      transport = _NotificationTransport(totalCount: total);
      syncState = _MemorySyncState();
      return controller = NotificationsController(
        NotificationRepository(
          api: NotificationsApi(
              ApiClient(transport: transport, tokenReader: () => null)),
          syncState: syncState,
        ),
        onServerChanged: () => badgeRefreshes++,
      );
    }


    Future<NotificationsState> settled() async {
      for (var i = 0; i < 50 && controller.state.isLoading; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return controller.state.value!;
    }

    test('first page, then next page without duplicates', () async {
      build(3);
      var state = await settled();
      // Newest first (fixture: n-2 is newer than n-1, n-3 oldest).
      expect(state.items.map((n) => n.id), ['n-2', 'n-1']);
      expect(state.hasMore, isTrue);

      await controller.loadMore();
      state = controller.state.value!;
      expect(state.items.map((n) => n.id), ['n-2', 'n-1', 'n-3']);
      expect(state.hasMore, isFalse);

      // Fetching a page again must not duplicate rows.
      transport.repeatPage = true;
      await controller.refresh();
      await settled();
      expect(controller.state.value!.server.map((n) => n.id).toSet(),
          hasLength(controller.state.value!.server.length));
    });

    test('empty result', () async {
      build(0);
      final state = await settled();
      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('a page that adds nothing new ends paging', () async {
      build(100);
      await settled();
      transport.repeatPage = true;
      await controller.loadMore();
      expect(controller.state.value!.hasMore, isFalse);
    });

    test('load-more failure keeps the loaded list and reports the error',
        () async {
      build(3);
      await settled();
      transport.failGraphQl = true;
      await controller.loadMore();
      final state = controller.state.value!;
      expect(state.server, hasLength(2));
      expect(state.moreError, isNotNull);
      expect(state.hasMore, isTrue);
    });

    test('mark read updates the list in place and refreshes the badge',
        () async {
      build(3);
      final state = await settled();
      await controller.markRead(state.server.first);
      expect(controller.state.value!.server.first.unread, isFalse);
      expect(controller.state.value!.server[1].unread, isTrue);
      expect(badgeRefreshes, 1);
      expect(transport.rest.single.toString(), 'PATCH /notifications/n-1/read');
    });

    test('mark all read updates every row and refreshes the badge', () async {
      build(3);
      await settled();
      await controller.markAllRead();
      expect(controller.state.value!.items.any((n) => n.unread), isFalse);
      expect(badgeRefreshes, 1);
    });

    test('offline: server read failure leaves the row unread', () async {
      build(3);
      final state = await settled();
      transport.failRest = true;
      await controller.markRead(state.server.first);
      expect(controller.state.value!.server.first.unread, isTrue);
    });

    test('offline: local notifications still shown', () async {
      build(3);
      transport.failGraphQl = true;
      transport.failWith = const ApiException.network();
      await NotificationRepository(
        api: NotificationsApi(
            ApiClient(transport: transport, tokenReader: () => null)),
        syncState: syncState,
      ).addLocal('local one');
      await controller.refresh();
      final state = await settled();
      expect(state.items.map((n) => n.text), ['local one']);
    });
  });
}

class _NotificationTransport implements ApiTransport {
  _NotificationTransport({required this.totalCount});

  final int totalCount;
  final List<ApiRequest> graphQl = <ApiRequest>[];
  final List<ApiRequest> rest = <ApiRequest>[];
  bool repeatPage = false;
  bool failGraphQl = false;
  bool failRest = false;
  ApiException failWith = const ApiException(
      kind: ApiErrorKind.server, message: 'boom', statusCode: 500);

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    if (request.path == Env.effectiveGraphQlEndpoint) {
      graphQl.add(request);
      if (failGraphQl) throw failWith;
      final body = request.body! as Map<String, dynamic>;
      if ((body['query'] as String).contains('notificationBadges')) {
        return const ApiResponse(statusCode: 200, data: <String, dynamic>{
          'data': <String, dynamic>{
            'notificationBadges': <String, dynamic>{
              'unreadCount': 7,
              'hasUnread': true,
            },
          },
        });
      }
      final variables = body['variables'] as Map<String, dynamic>;
      final page = repeatPage ? 1 : variables['page'] as int;
      final ids = page == 1 ? ['n-1', 'n-2'] : ['n-3'];
      return ApiResponse(statusCode: 200, data: <String, dynamic>{
        'data': <String, dynamic>{
          'notifications': <String, dynamic>{
            'items': totalCount == 0
                ? <Object>[]
                : [
                    for (final id in ids)
                      <String, dynamic>{
                        'id': id,
                        'type': 'order',
                        'title': 'T $id',
                        'message': 'M $id',
                        'isRead': false,
                        'createdAt': page == 1
                            ? '2026-11-0${ids.indexOf(id) + 2}T00:00:00Z'
                            : '2026-11-01T00:00:00Z',
                        'deepLink': '/orders/o-1',
                      }
                  ],
            'page': variables['page'],
            'pageSize': 2,
            'totalCount': totalCount,
          },
        },
      });
    }
    rest.add(request);
    if (failRest) throw const ApiException.network();
    return const ApiResponse(statusCode: 200);
  }
}

class _MemorySyncState implements SyncStateDao {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> get(String key) async => _values[key];

  @override
  Future<void> set(String key, String value) async => _values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
