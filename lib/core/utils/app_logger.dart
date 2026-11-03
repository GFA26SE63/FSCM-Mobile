import 'package:flutter/foundation.dart';

/// In-memory ring buffer that stores diagnostic logs so developers and testers
/// can view and copy full error stack traces directly on a physical phone.
class AppLogger {
  AppLogger._();

  static const int _maxLogs = 100;
  static final List<String> _logs = <String>[];

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$timestamp] $message';
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    if (kDebugMode) {
      debugPrint(entry);
    }
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write('\nChi tiết: $error');
    }
    if (stack != null) {
      buffer.write('\n$stack');
    }
    log('[ERROR] ${buffer.toString()}');
  }

  static List<String> get logs => List<String>.unmodifiable(_logs);

  static String exportAll() {
    if (_logs.isEmpty) return 'Chưa có nhật ký nào được ghi.';
    return _logs.join('\n');
  }

  static void clear() {
    _logs.clear();
  }
}
