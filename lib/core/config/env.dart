/// Build-time configuration, passed with `--dart-define` (see README).
///
/// ```
/// flutter run --dart-define=USE_MOCK=false \
///   --dart-define=API_BASE_URL=https://fscm-api.azurewebsites.net/api/v1 \
///   --dart-define=FLAVOR=staging
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
    defaultValue: 'https://localhost:7027/api/v1',
  );

  /// When true (default) the app talks to the in-process [MockApi]
  /// (lib/data/mock) so it runs without the ASP.NET Core backend.
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: false);

  /// Simulated network latency of the mock backend.
  static const int mockLatencyMs = 350;

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
