import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/remote/notifications_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads all pages and uses PATCH to mark notifications read', () async {
    final transport = _NotificationTransport();
    final api = NotificationsApi(
      ApiClient(transport: transport, tokenReader: () => null),
    );

    final notifications = await api.list();
    expect(notifications.map((item) => item.id), ['notice-1', 'notice-2']);
    expect(transport.requests.map((request) => request.query?['page']), [1, 2]);

    await api.markRead('notice-1');
    await api.markAllRead();
    expect(transport.requests.skip(2).map((request) => request.toString()), [
      'PATCH /notifications/notice-1/read',
      'PATCH /notifications/read-all',
    ]);
  });
}

class _NotificationTransport implements ApiTransport {
  final requests = <ApiRequest>[];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (request.method == 'PATCH') return const ApiResponse(statusCode: 200);
    return ApiResponse(
      statusCode: 200,
      data: {
        'totalCount': 2,
        'items': [
          {'id': 'notice-${request.query?['page']}'},
        ],
      },
    );
  }
}
