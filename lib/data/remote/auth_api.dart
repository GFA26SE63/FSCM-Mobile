import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

/// Mobile Auth & Identity API client (`SPRINT_1_FRONTEND_MOBILE_API_GUIDE.md`
/// §3.2, §3.3, §5.1).
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  /// `POST /api/v1/auth/login` with `{ "email": ..., "password": ... }`.
  /// Also sends `phone` when logging in from the Customer tab by phone number.
  Future<Session> login({
    required String email,
    required String password,
    String? phone,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPhone = (phone ?? '').replaceAll(RegExp(r'\s+'), '');
    final data = await _client.post(
      Endpoints.authLogin,
      body: <String, dynamic>{
        'email': normalizedEmail,
        if (normalizedPhone.isNotEmpty) 'phone': normalizedPhone,
        'password': password,
      },
    );
    return Session.fromJson(asMap(data));
  }

  /// `POST /api/v1/auth/refresh` with `{ "refreshToken": ... }`.
  Future<Session> refresh(String refreshToken) async {
    final data = await _client.post(
      Endpoints.authRefresh,
      body: <String, dynamic>{'refreshToken': refreshToken},
    );
    return Session.fromJson(asMap(data));
  }

  /// `GET /api/v1/auth/me` -> returns current authenticated user profile & scope.
  Future<AppUser> me() async {
    final data = await _client.get(Endpoints.authMe);
    return AppUser.fromJson(asMap(data));
  }

  /// `POST /api/v1/auth/logout` with `{ "refreshToken": ... }`.
  Future<void> logout({String? refreshToken}) async {
    await _client.post(
      Endpoints.authLogout,
      body: <String, dynamic>{'refreshToken': refreshToken ?? ''},
    );
  }

  /// `POST /api/v1/auth/activate` with `{ "token": ..., "password": ... }`.
  Future<void> activate({
    required String token,
    required String password,
  }) async {
    await _client.post(
      Endpoints.authActivate,
      body: <String, dynamic>{
        'token': token,
        'password': password,
      },
    );
  }

  /// `POST /api/v1/auth/password-reset/request` with `{ "email": ... }`.
  Future<void> requestPasswordReset(String email) async {
    await _client.post(
      Endpoints.authPasswordResetRequest,
      body: <String, dynamic>{'email': email.trim()},
    );
  }

  /// `POST /api/v1/auth/password-reset/confirm` with `{ "token": ..., "password": ... }`.
  Future<void> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    await _client.post(
      Endpoints.authPasswordResetConfirm,
      body: <String, dynamic>{
        'token': token,
        'password': password,
      },
    );
  }

  Future<void> requestOtp(String phone) async {
    await _client.post(
      Endpoints.authOtpRequest,
      body: <String, dynamic>{'phone': phone.replaceAll(RegExp(r'\s+'), '')},
    );
  }

  /// Returns a short-lived setup token used by [setPassword].
  Future<String> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final data = await _client.post(
      Endpoints.authOtpVerify,
      body: <String, dynamic>{
        'phone': phone.replaceAll(RegExp(r'\s+'), ''),
        'code': code.trim(),
      },
    );
    return asStr(asMap(data)['setupToken']);
  }

  Future<Session> setPassword({
    required String setupToken,
    required String password,
    String? phone,
  }) async {
    final data = await _client.post(
      Endpoints.authSetPassword,
      body: <String, dynamic>{
        'setupToken': setupToken,
        'password': password,
        if (phone != null) 'phone': phone.replaceAll(RegExp(r'\s+'), ''),
      },
    );
    return Session.fromJson(asMap(data));
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
}
