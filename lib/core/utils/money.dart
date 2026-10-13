/// vi-VN money formatting: `1.234.000đ` (dot as thousands separator,
/// no decimals). Hand-written so it works without intl locale init.
class Money {
  Money._();

  static String format(num amount) {
    final rounded = amount.round();
    final negative = rounded < 0;
    final digits = rounded.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${negative ? '−' : ''}$buf' 'đ';
  }

  /// Discount style: `−720.000đ` (0 stays `0đ`).
  static String minus(num amount) =>
      amount == 0 ? '0đ' : '−${format(amount.abs())}';

  /// Short form for charts / podium: `245,7 tr`, `1,2 tỷ`.
  static String short(num amount) {
    final a = amount.abs();
    if (a >= 1000000000) return '${_oneDecimal(amount / 1000000000)} tỷ';
    if (a >= 1000000) return '${_oneDecimal(amount / 1000000)} tr';
    if (a >= 1000) return '${_oneDecimal(amount / 1000)} k';
    return amount.round().toString();
  }

  static String _oneDecimal(num v) {
    final s = v.toStringAsFixed(1);
    final trimmed = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    return trimmed.replaceAll('.', ',');
  }

  /// Parses user input like `35.000.000` or `35000000`.
  static int? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }
}
