/// Display formatting for quantities (cartons, units). Presentation only: the
/// stored value is never rounded or changed. vi-VN separators: `.` groups
/// thousands, `,` starts the decimals. Integral values show no decimals
/// (`1.0` → `1`); fractions keep up to 3 meaningful digits (`2.5` → `2,5`).
String formatQuantity(Object? value) {
  if (value is! num) return value?.toString() ?? '';
  if (!value.isFinite) return '0';
  final fixed =
      value.abs().toStringAsFixed(3); // drops float noise (0.30000000000000004)
  final parts = fixed.split('.');
  final grouped = StringBuffer();
  final digits = parts[0];
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  final fraction = parts[1].replaceFirst(RegExp(r'0+$'), '');
  final isZero = fraction.isEmpty && digits.replaceAll('0', '').isEmpty;
  final sign = value < 0 && !isZero ? '−' : '';
  return '$sign$grouped${fraction.isEmpty ? '' : ',$fraction'}';
}
