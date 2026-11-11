import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'print_session.dart';

PrintSession openPrintSession() {
  if (defaultTargetPlatform != TargetPlatform.android) {
    throw UnsupportedError(
        'Thiết bị này chưa hỗ trợ in tem trực tiếp. Hãy in các tem mới từ Portal.');
  }
  return _AndroidPrintSession();
}

class _AndroidPrintSession implements PrintSession {
  static const _channel = MethodChannel('fscm/label_print');
  @override
  Future<void> showHtml(String html, String title) async {
    await _channel
        .invokeMethod<void>('printHtml', {'html': html, 'title': title});
  }

  @override
  void close() {}
}
