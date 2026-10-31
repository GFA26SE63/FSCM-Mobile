/// Build-time configuration.
///
/// These are compile-time constants: they come from `--dart-define`, or from a JSON file given to
/// `--dart-define-from-file`. Nothing here is read from disk at runtime, so a configuration file
/// the app was not built with has no effect at all - which is worth knowing, because `env/` looks
/// exactly like a file that would be.
///
/// The usual way to run against a backend is therefore:
///
/// ```
/// flutter run --dart-define-from-file=env/appsettings.json
/// ```
///
/// with `env/appsettings.json` holding `API_BASE_URL` and `USE_MOCK` (see
/// `env/development.example.json`). One flag at a time also works:
///
/// ```
/// flutter run --dart-define=USE_MOCK=false \
///   --dart-define=API_BASE_URL=https://10.0.2.2:7027/api/v1
/// ```
enum AppFlavor { dev, staging, prod }

class Env {
  Env._();

  /// dev | staging | prod.
  static const String flavorName =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  /// REST base URL including the `/api/v1` prefix (SPEC section 8).
  ///
  /// Defaults to `https://localhost:7027/api/v1`.
  /// On a physical Android phone connected via USB, forward the port with:
  /// `adb reverse tcp:7027 tcp:7027` (handled automatically by `run_android.ps1`
  /// and the VS Code launch configuration).
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
