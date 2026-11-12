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

  /// Absolute GraphQL endpoint. This intentionally does not inherit the
  /// REST `/api/v1` prefix.
  static const String graphQlEndpoint = String.fromEnvironment(
    'GRAPHQL_ENDPOINT',
    defaultValue: '',
  );

  static String? _runtimeApiBaseUrl;

  /// Effective URL in use: falls back to [apiBaseUrl] if not overridden at runtime.
  static String get effectiveApiBaseUrl => _runtimeApiBaseUrl ?? apiBaseUrl;

  /// Uses the separately configured GraphQL endpoint for normal builds.
  /// A runtime REST override represents a different server, so derive its
  /// GraphQL endpoint from that same server instead of retaining the build
  /// endpoint.
  static String get effectiveGraphQlEndpoint => graphQlEndpointFor(
        effectiveApiBaseUrl,
        configuredEndpoint: _runtimeApiBaseUrl == null ? graphQlEndpoint : '',
      );

  static void setRuntimeApiBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _runtimeApiBaseUrl = null;
    } else {
      _runtimeApiBaseUrl = url.trim();
    }
  }

  static String graphQlEndpointFor(
    String restBaseUrl, {
    String configuredEndpoint = '',
  }) {
    final configured = configuredEndpoint.trim();
    if (configured.isNotEmpty) return configured;

    final restBase = Uri.parse(restBaseUrl);
    final segments = restBase.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.length < 2 ||
        segments[segments.length - 2] != 'api' ||
        segments.last != 'v1') {
      throw ArgumentError.value(
        restBaseUrl,
        'restBaseUrl',
        'The API base URL must end with /api/v1.',
      );
    }

    return Uri(
      scheme: restBase.scheme,
      userInfo: restBase.userInfo,
      host: restBase.host,
      port: restBase.hasPort ? restBase.port : null,
      pathSegments: <String>[...segments.take(segments.length - 2), 'graphql'],
    ).toString();
  }

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

  /// Client key for VietMap tiles, Autocomplete v4 and Place v4.
  /// Never embed the backend's private server credential here.
  static const String vietMapApiKey = String.fromEnvironment('VIETMAP_API_KEY');
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
