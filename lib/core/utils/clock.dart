import 'package:fscm_mobile/core/config/env.dart';

/// Single source of "now" for the app.
///
/// In mock mode the clock starts at the prototype's demo moment
/// (27/09/2026 10:12) and then ticks in real time, so seeded data such as
/// overdue debts (due 22/09) and document codes (`DC-260926-01`) stay
/// consistent with the approved UI prototypes.
class AppClock {
  AppClock._();

  static final DateTime mockEpoch = DateTime(2026, 9, 27, 10, 12);
  static final Stopwatch _watch = Stopwatch()..start();

  static DateTime now() {
    if (Env.useMock) return mockEpoch.add(_watch.elapsed);
    return DateTime.now();
  }

  static DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}
