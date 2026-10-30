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

  /// SharedPreferences key used to persist a runtime server URL override on a
  /// physical phone when testing over Wi-Fi / LAN without USB.
  static const String customApiBaseUrlPrefKey = 'custom_api_base_url';

  /// dev | staging | prod.
  static const String flavorName =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  /// REST base URL including the `/api/v1` prefix (SPEC section 8).
  ///
  /// Defaults to `https://localhost:7027/api/v1`.
  /// On a physical Android phone connected via USB, `adb reverse tcp:7027 tcp:7027`
  /// is configured automatically during `assembleDebug` and by `run_android.ps1`.
  /// When running over Wi-Fi without USB, [DioTransport] automatically falls back
  /// to [lanHost] / `10.0.2.2` or the user-configured [runtimeApiBaseUrl].
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7027/api/v1',
  );

  /// Default LAN IP of the development machine on Wi-Fi, used as an automatic
  /// fallback when `localhost` refuses connection on a physical phone.
  static const String lanHost = String.fromEnvironment(
    'LAN_HOST',
    defaultValue: '10.87.16.166',
  );

  static String? _runtimeApiBaseUrl;

  /// Optional runtime override set from the Login screen or auto-discovery.
  static String? get runtimeApiBaseUrl => _runtimeApiBaseUrl;

  /// Active base URL (runtime override if set, otherwise [apiBaseUrl]).
  static String get effectiveApiBaseUrl => _runtimeApiBaseUrl ?? apiBaseUrl;

  /// Sets or clears the runtime API base URL override.
  static void setRuntimeApiBaseUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      _runtimeApiBaseUrl = null;
      return;
    }
    _runtimeApiBaseUrl = normalizeApiBaseUrl(raw);
  }

  /// Normalizes a user-entered host, IP, or URL into `https://host:port/api/v1`.
  static String normalizeApiBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return apiBaseUrl;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      // Default to https:7027 unless port 5246 is explicitly given.
      if (s.contains(':5246')) {
        s = 'http://$s';
      } else if (!s.contains(':')) {
        s = 'https://$s:7027';
      } else {
        s = 'https://$s';
      }
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!s.endsWith('/api/v1')) {
      s = '$s/api/v1';
    }
    return s;
  }

  /// Candidate base URLs tried automatically on mobile when `localhost`
  /// refuses connection (e.g. different phone without `adb reverse`, Wi-Fi LAN,
  /// or Android emulator).
  static List<String> get fallbackApiBaseUrls {
    final urls = <String>[
      if (_runtimeApiBaseUrl != null) _runtimeApiBaseUrl!,
      apiBaseUrl,
      if (lanHost.isNotEmpty) 'https://$lanHost:7027/api/v1',
      if (lanHost.isNotEmpty) 'http://$lanHost:5246/api/v1',
      'https://10.0.2.2:7027/api/v1',
      'http://10.0.2.2:5246/api/v1',
      'http://localhost:5246/api/v1',
    ];
    final seen = <String>{};
    return urls.where((u) => seen.add(u)).toList();
  }

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
