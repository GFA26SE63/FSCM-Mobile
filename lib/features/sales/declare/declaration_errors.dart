import 'package:fscm_mobile/core/network/api_exception.dart';

/// A duplicate-contact rejection of a retailer declaration, worded for Sales.
class DeclarationConflict {
  const DeclarationConflict(this.field, this.message);

  /// 'phone', 'email', 'name' or null when the server did not say which one.
  final String? field;
  final String message;
}

const Map<String, String> _messages = <String, String>{
  'phone':
      'Số điện thoại này đã được dùng cho một điểm bán hoặc tài khoản khác. Vui lòng nhập số khác.',
  'email':
      'Email này đã được dùng cho một điểm bán hoặc tài khoản khác. Vui lòng nhập email khác.',
  'name': 'Đã có điểm bán cùng tên và địa chỉ trong hệ thống.',
};

/// Maps a 409 from POST/PUT declaration to a Vietnamese message the screen
/// owns, instead of showing the server's text. Returns null for other errors.
///
/// Reads the `field` extension (or the `errors` keys) sent by the backend; an
/// older backend without it still gets a Vietnamese message, just not tied to
/// a single input.
DeclarationConflict? declarationConflictOf(ApiException e) {
  if (e.kind != ApiErrorKind.conflict) return null;
  final field = e.problemDetails?['field']?.toString() ??
      e.errors.keys.cast<String?>().firstWhere(
            (key) => _messages.containsKey(key),
            orElse: () => null,
          );
  if (field != null && _messages.containsKey(field)) {
    return DeclarationConflict(field, _messages[field]!);
  }
  final text = '${e.title ?? ''} ${e.message}'.toLowerCase();
  if (text.contains('phone or email') ||
      text.contains('duplicates existing') ||
      text.contains('already assigned')) {
    return const DeclarationConflict(null,
        'Số điện thoại hoặc email đã được dùng cho một điểm bán hoặc tài khoản khác. Vui lòng kiểm tra lại.');
  }
  return null;
}
