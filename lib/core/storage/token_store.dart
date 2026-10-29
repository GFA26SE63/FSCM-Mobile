import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Keeps the session (access token + refresh token + user JSON) in the platform
/// keystore and mirrors it in memory so the API client can read it synchronously.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _sessionKey = 'fscm_session';

  Map<String, dynamic>? _cached;

  String? get accessToken => _cached?['accessToken'] as String?;

  String? get refreshToken => _cached?['refreshToken'] as String?;

  Map<String, dynamic>? get cachedSession => _cached;

  Future<Map<String, dynamic>?> load() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cached = decoded;
        return decoded;
      }
    } catch (e) {
      debugPrint('TokenStore.load warning: $e');
      // Corrupted entry or keystore reset: start logged out.
      await clear();
    }
    return null;
  }

  Future<void> save(Map<String, dynamic> session) async {
    _cached = session;
    try {
      await _storage.write(key: _sessionKey, value: jsonEncode(session));
    } catch (e) {
      debugPrint('TokenStore.save warning (persisting to storage failed): $e');
    }
  }

  Future<void> clear() async {
    _cached = null;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('TokenStore.clear warning: $e');
    }
  }
}
