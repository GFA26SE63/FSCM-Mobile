import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Overridden in `main()` once [SharedPreferences.getInstance] completes.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});

final deviceIdentityProvider = Provider<DeviceIdentity>((ref) {
  return DeviceIdentity(ref.watch(sharedPreferencesProvider));
});

/// Stable short device code used in offline order codes
/// `OFF-{device}-{0000}` (SPEC section 3).
class DeviceIdentity {
  DeviceIdentity(this._prefs);

  final SharedPreferences _prefs;

  static const String _deviceKey = 'device_code';
  static const String _installKey = 'install_id';

  /// 4 upper-case alphanumerics, e.g. `M3F7`.
  String get deviceCode {
    final existing = _prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final hex = const Uuid().v4().replaceAll('-', '').toUpperCase();
    final code = 'M${hex.substring(0, 3)}';
    unawaited(_prefs.setString(_deviceKey, code));
    return code;
  }

  /// Full UUID for push-registration (`POST /devices`).
  String get installId {
    final existing = _prefs.getString(_installKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    unawaited(_prefs.setString(_installKey, id));
    return id;
  }
}
