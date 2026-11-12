import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'print_session.dart';
import 'printing_native.dart' if (dart.library.js_interop) 'printing_web.dart'
    as platform;

final labelPrinterProvider =
    Provider<LabelPrinter>((ref) => LabelPrinter(ref.watch(apiClientProvider)));

class LabelPrinter {
  LabelPrinter(this._client, {PrintSession Function()? openSession})
      : _openSession = openSession ?? platform.openPrintSession;
  final ApiClient _client;
  final PrintSession Function() _openSession;

  Future<void> printLabel(String code) async {
    if (!IdFormat.isLabel(code)) throw ArgumentError('Mã tem không hợp lệ.');
    final session = _openSession();
    try {
      final html =
          await _client.get('/qr-labels/${Uri.encodeComponent(code)}/print');
      if (html is! String || !html.toLowerCase().contains('<html')) {
        throw const ApiException(
            kind: ApiErrorKind.server,
            message: 'Bản in tem từ máy chủ không hợp lệ.');
      }
      await session.showHtml(html, code);
    } catch (_) {
      session.close();
      rethrow;
    }
  }
}
