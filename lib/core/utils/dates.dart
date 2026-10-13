import 'package:intl/intl.dart';

/// Date formatting used across screens (patterns copied from the prototype:
/// `10:12 27/09`, `27/09/2026`).
class AppDates {
  AppDates._();

  static final DateFormat _timeDay = DateFormat('HH:mm dd/MM');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dayMonth = DateFormat('dd/MM');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _iso = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  /// `10:12 27/09`
  static String timeDay(DateTime? d) => d == null ? '—' : _timeDay.format(d);

  /// `27/09/2026`
  static String date(DateTime? d) => d == null ? '—' : _date.format(d);

  /// `27/09`
  static String dayMonth(DateTime? d) => d == null ? '—' : _dayMonth.format(d);

  /// `10:12`
  static String time(DateTime? d) => d == null ? '—' : _time.format(d);

  /// Local ISO-8601 without offset, the format used by the API JSON.
  static String iso(DateTime d) => _iso.format(d);

  static String isoDate(DateTime d) => _isoDate.format(d);

  static DateTime? tryParse(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Whole days from [from] to [to] (date part only).
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
