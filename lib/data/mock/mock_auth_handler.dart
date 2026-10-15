import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/core/auth/session.dart';

/// `/auth/*`, `/me`, `/devices`, `/notifications`.
class MockAuthHandler extends MockHandler {
  MockAuthHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;
    if (r.matches('POST', '/auth/login')) {
      final u =
          store.userByLogin(asStr(r.body['phone']), asStr(r.body['password']));
      if (u == null) {
        return MockReply.problem(401, 'Số điện thoại hoặc mật khẩu không đúng.',
            title: 'Unauthorized');
      }
      return MockReply.ok(_session(u));
    }
    if (r.matches('POST', '/auth/otp/request')) return MockReply.noContent();
    if (r.matches('POST', '/auth/otp/verify')) {
      return MockReply.ok(<String, dynamic>{'setupToken': 'mock-setup-token'});
    }
    if (r.matches('POST', '/auth/password')) {
      return MockReply.ok(_session(store.users.first));
    }
    if (r.matches('POST', '/auth/logout')) return MockReply.noContent();

    if (user == null) return null;
    if (r.matches('GET', '/me')) return MockReply.ok(user.toAppUser().toJson());
    if (r.matches('POST', '/devices')) return MockReply.noContent();

    if (r.matches('GET', '/notifications')) {
      final list = List<AppNotification>.of(store.notificationsFor(user))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return MockReply.page(list.map((n) => n.toJson()).toList());
    }
    if (r.matches('POST', '/notifications/*/read')) {
      final id = r.segments[1];
      final list = store.notificationsFor(user);
      final i = list.indexWhere((n) => n.id == id);
      if (i >= 0) list[i] = list[i].markRead();
      return MockReply.noContent();
    }
    return null;
  }

  Map<String, dynamic> _session(MockUser u) => Session(
        accessToken: u.token,
        expiresAt: store.now().add(const Duration(days: 30)),
        user: u.toAppUser(),
      ).toJson();
}
