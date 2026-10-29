import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// `/auth/*`, `/me`, `/devices`, `/notifications`.
class MockAuthHandler extends MockHandler {
  MockAuthHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;

    if (r.matches('POST', '/auth/login')) {
      final email = asStr(r.body['email']);
      final phone = asStr(r.body['phone']);
      final password = asStr(r.body['password']);
      final identifier = email.isNotEmpty ? email : phone;
      final u = store.userByLogin(
        identifier,
        password,
        fallbackPhone: phone,
      );
      if (u == null) {
        final msg = email.contains('@')
            ? 'Email hoặc mật khẩu không đúng.'
            : 'Số điện thoại hoặc mật khẩu không đúng.';
        return MockReply.problem(401, msg, title: 'Unauthorized');
      }
      return MockReply.ok(_session(u));
    }

    if (r.matches('POST', '/auth/refresh')) {
      final refreshToken = asStr(r.body['refreshToken']);
      final u = store.userByRefreshToken(refreshToken) ?? user;
      if (u == null) {
        return MockReply.problem(
          401,
          'Refresh token không hợp lệ hoặc đã hết hạn.',
          title: 'Unauthorized',
        );
      }
      return MockReply.ok(_session(u));
    }

    if (r.matches('POST', '/auth/activate')) {
      return MockReply.noContent();
    }

    if (r.matches('POST', '/auth/password-reset/request')) {
      return MockReply.noContent();
    }
    if (r.matches('POST', '/auth/password-reset/confirm')) {
      return MockReply.noContent();
    }

    if (r.matches('POST', '/auth/otp/request')) return MockReply.noContent();
    if (r.matches('POST', '/auth/otp/verify')) {
      final code = asStr(r.body['code']);
      if (code.length < 6) {
        return MockReply.problem(400, 'Vui lòng nhập đủ 6 chữ số mã OTP.');
      }
      return MockReply.ok(<String, dynamic>{'setupToken': 'mock-setup-token'});
    }
    if (r.matches('POST', '/auth/password')) {
      final phone = asStr(r.body['phone']);
      final matched =
          (phone.isNotEmpty ? store.userByIdentifier(phone) : null) ??
              store.users.firstWhere(
                (u) => u.role == UserRole.retailer,
                orElse: () => store.users.first,
              );
      return MockReply.ok(_session(matched));
    }
    if (r.matches('POST', '/auth/logout')) return MockReply.noContent();

    if (user == null) return null;
    if (r.matches('GET', '/auth/me') || r.matches('GET', '/me')) {
      return MockReply.ok(user.toAppUser().toJson());
    }
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
        expiresAt: store.now().add(const Duration(minutes: 60)),
        refreshToken: u.refreshToken,
        refreshTokenExpiresAt: store.now().add(const Duration(days: 30)),
        user: u.toAppUser(),
      ).toJson();
}
