import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

/// Mobile auth facade in front of Entra External ID + `GET /me`,
/// `POST /devices` (push registration).
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// Phone + password. Accounts are created by Admin; first login uses OTP
  /// (see [requestOtp] / [verifyOtp] / [setPassword]).
  Future<Session> login(
      {required String phone, required String password}) async {
    final data = await _client.post(
      Endpoints.authLogin,
      body: <String, dynamic>{'phone': phone, 'password': password},
    );
    return Session.fromJson(asMap(data));
  }

  Future<void> requestOtp(String phone) async {
    await _client.post(Endpoints.authOtpRequest,
        body: <String, dynamic>{'phone': phone});
  }

  /// Returns a short-lived setup token used by [setPassword].
  Future<String> verifyOtp(
      {required String phone, required String code}) async {
    final data = await _client.post(
      Endpoints.authOtpVerify,
      body: <String, dynamic>{'phone': phone, 'code': code},
    );
    return asStr(asMap(data)['setupToken']);
  }

  Future<Session> setPassword(
      {required String setupToken, required String password}) async {
    final data = await _client.post(
      Endpoints.authSetPassword,
      body: <String, dynamic>{'setupToken': setupToken, 'password': password},
    );
    return Session.fromJson(asMap(data));
  }

  Future<AppUser> me() async {
    final data = await _client.get(Endpoints.me);
    return AppUser.fromJson(asMap(data));
  }

  Future<void> registerDevice({
    required String installId,
    required String platform,
    String? pushToken,
  }) async {
    await _client.post(
      Endpoints.devices,
      body: <String, dynamic>{
        'installId': installId,
        'platform': platform,
        'pushToken': pushToken,
      },
    );
  }

  Future<void> logout() async {
    await _client.post(Endpoints.authLogout);
  }
}
