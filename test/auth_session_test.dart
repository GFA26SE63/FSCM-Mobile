import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';

void main() {
  test('authentication session preserves access and refresh tokens', () {
    final session = Session.fromJson(<String, dynamic>{
      'accessToken': 'access-token',
      'accessTokenExpiresAt': '2026-10-31T01:00:00Z',
      'refreshToken': 'refresh-token',
      'refreshTokenExpiresAt': '2026-11-30T00:00:00Z',
      'user': <String, dynamic>{
        'id': 'user-id',
        'fullName': 'Điểm bán An Phú',
        'email': 'retailer@example.com',
        'role': 'Retailer',
      },
    });

    final persisted = session.toJson();
    expect(persisted['accessToken'], 'access-token');
    expect(persisted['refreshToken'], 'refresh-token');
    expect(persisted['refreshTokenExpiresAt'], '2026-11-30T00:00:00.000Z');
  });
}
