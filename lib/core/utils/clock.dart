/// Single source of "now" for the app.
class AppClock {
  AppClock._();

  static DateTime now() => DateTime.now();

  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}
