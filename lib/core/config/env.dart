/// Build-time configuration, passed with `--dart-define` (see README).
///
/// ```
/// flutter run --dart-define-from-file=env/appsettings.json
/// ```
enum AppFlavor { dev, staging, prod }

class Env {
  Env._();

  /// dev | staging | prod.
  static const String flavorName =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  /// REST base URL including the `/api/v1` prefix (SPEC section 8).
  /// `10.0.2.2` is the host machine seen from the Android emulator.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5080/api/v1',
  );

  /// Web-type OAuth client used as the server client ID on Android and iOS.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// iOS-type OAuth client ID. Android discovers its client from package name
  /// and signing certificate, so it does not need an Android client ID here.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  /// Desktop OAuth credentials used only by the Windows system-browser flow.
  /// A desktop client secret is public by design and must not grant server access.
  static const String googleWindowsClientId = String.fromEnvironment(
    'GOOGLE_WINDOWS_CLIENT_ID',
    defaultValue: '',
  );
  static const String googleWindowsClientSecret = String.fromEnvironment(
    'GOOGLE_WINDOWS_CLIENT_SECRET',
    defaultValue: '',
  );
  static const int googleWindowsRedirectPort = int.fromEnvironment(
    'GOOGLE_WINDOWS_REDIRECT_PORT',
    defaultValue: 8000,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Offline order queue: automatic retries before the order waits for a
  /// manual "Đồng bộ thủ công".
  static const int syncMaxAutoRetries = 6;

  /// Periodic tick that retries failed queue entries whose backoff elapsed.
  static const Duration syncRetryTick = Duration(seconds: 30);

  static AppFlavor get flavor {
    switch (flavorName) {
      case 'prod':
        return AppFlavor.prod;
      case 'staging':
        return AppFlavor.staging;
      default:
        return AppFlavor.dev;
    }
  }

  static bool get isProd => flavor == AppFlavor.prod;
}
