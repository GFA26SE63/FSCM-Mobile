/// Carton quantities as the server keeps them.
///
/// The physical schema stores every quantity as `numeric(18,3)`, so a gather
/// can legitimately be 12.5 cartons. Reading those into `int` silently
/// truncated them, and a picking sheet that is short by half a carton reads as
/// complete, so they are carried as `double` and formatted here.
class Qty {
  const Qty._();

  /// `12`, `12.5`, `12.25` - trailing zeros dropped, three decimals at most.
  static String format(num value) {
    final fixed = value.toStringAsFixed(3);
    if (!fixed.contains('.')) return fixed;
    final trimmed =
        fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  /// `12 thùng`, for the many places that read as a sentence.
  static String cartons(num value) => '${format(value)} thùng';

  /// Rounds away the noise `numeric(18,3)` arithmetic leaves behind, so a
  /// comparison does not call 10.0000000001 short of 10.
  static bool covers(num picked, num required) =>
      (picked - required) >= -0.0005;
}
