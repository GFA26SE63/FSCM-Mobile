import 'dart:js_interop';
import 'print_session.dart';

@JS('window.open')
external _PrintWindow? _openWindow(JSString url, JSString target);

extension type _PrintWindow._(JSObject _) implements JSObject {
  external _PrintDocument get document;
  external void focus();
  external void print();
  external void close();
}

extension type _PrintDocument._(JSObject _) implements JSObject {
  external void write(JSString html);
  external void close();
}

PrintSession openPrintSession() {
  // Open synchronously from the user's click, before the authenticated HTML request.
  final window = _openWindow(''.toJS, '_blank'.toJS);
  if (window == null) {
    throw UnsupportedError(
        'Trình duyệt đang chặn cửa sổ in. Hãy cho phép cửa sổ bật lên rồi thử lại.');
  }
  return _WebPrintSession(window);
}

class _WebPrintSession implements PrintSession {
  _WebPrintSession(this.window);
  final _PrintWindow window;
  @override
  Future<void> showHtml(String html, String title) async {
    window.document.write(html.toJS);
    window.document.close();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    window.focus();
    window.print();
  }

  @override
  void close() => window.close();
}
