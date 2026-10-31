import 'dart:io' show Platform;

import 'package:google_sign_in/google_sign_in.dart' as mobile_google;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as desktop_google;

import 'package:fscm_mobile/core/config/env.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  Future<void>? _mobileInitialization;

  Future<String> acquireIdToken() {
    if (Platform.isWindows) return _acquireWindowsIdToken();
    if (Platform.isAndroid || Platform.isIOS) return _acquireMobileIdToken();
    throw UnsupportedError(
        'Google sign-in is not configured for this platform.');
  }

  Future<String> _acquireMobileIdToken() async {
    if (Env.googleServerClientId.isEmpty ||
        (Platform.isIOS && Env.googleIosClientId.isEmpty)) {
      throw StateError('Google OAuth client IDs have not been configured.');
    }

    final signIn = mobile_google.GoogleSignIn.instance;
    _mobileInitialization ??= signIn.initialize(
      clientId: Platform.isIOS ? Env.googleIosClientId : null,
      serverClientId: Env.googleServerClientId,
    );
    await _mobileInitialization;

    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }
    return idToken;
  }

  Future<String> _acquireWindowsIdToken() async {
    if (Env.googleWindowsClientId.isEmpty ||
        Env.googleWindowsClientSecret.isEmpty) {
      throw StateError(
          'Google OAuth desktop credentials have not been configured.');
    }

    final signIn = desktop_google.GoogleSignIn(
      params: const desktop_google.GoogleSignInParams(
        clientId: Env.googleWindowsClientId,
        clientSecret: Env.googleWindowsClientSecret,
        redirectPort: Env.googleWindowsRedirectPort,
        scopes: <String>['openid', 'profile', 'email'],
      ),
    );
    final credentials = await signIn.signIn();
    final idToken = credentials?.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }
    return idToken;
  }
}
