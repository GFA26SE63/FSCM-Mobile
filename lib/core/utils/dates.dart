import 'package:intl/intl.dart';

/// Date formatting used across screens (patterns copied from the prototype:
/// `10:12 27/09`, `27/09/2026`).
class AppDates {
  AppDates._();

  static final DateFormat _timeDay = DateFormat('HH:mm dd/MM');
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dayMonth = DateFormat('dd/MM');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  // Business timestamps always display in Vietnam, independently of the device zone.
  static DateTime vietnamTime(DateTime d) =>
      d.toUtc().add(const Duration(hours: 7));

  // Calendar-only values (expiry/due dates) have no UTC marker and must not shift.
  static DateTime _calendarDate(DateTime d) => d.isUtc ? vietnamTime(d) : d;

  /// `10:12 27/09`
  static String timeDay(DateTime? d) =>
      d == null ? '—' : _timeDay.format(vietnamTime(d));

  /// `27/09/2026`
  static String date(DateTime? d) =>
      d == null ? '—' : _date.format(_calendarDate(d));

  /// `27/09`
  static String dayMonth(DateTime? d) =>
      d == null ? '—' : _dayMonth.format(_calendarDate(d));

  /// `10:12`
  static String time(DateTime? d) =>
      d == null ? '—' : _time.format(vietnamTime(d));

  /// Preserve the UTC marker so a cached timestamp is not reinterpreted as device-local.
  static String iso(DateTime d) => d.toIso8601String();

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

  /// Day-only key for an instant in Vietnam; UTC construction avoids device DST.
  static DateTime vietnamDay(DateTime instant) {
    final local = vietnamTime(instant);
    return DateTime.utc(local.year, local.month, local.day);
  }

  static bool isSameVietnamDay(DateTime a, DateTime b) =>
      vietnamDay(a) == vietnamDay(b);

  static int vietnamDaysBetween(DateTime from, DateTime to) =>
      vietnamDay(to).difference(vietnamDay(from)).inDays;

  /// Whole days from [from] to [to] (date part only).
  static int daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
