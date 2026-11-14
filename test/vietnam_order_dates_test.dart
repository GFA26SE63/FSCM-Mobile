import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/utils/dates.dart';

void main() {
  test('Sales today counts instants on the same Vietnam day across UTC midnight', () {
    final now = DateTime.parse('2026-11-15T01:00:00+07:00');
    expect(AppDates.isSameVietnamDay(DateTime.parse('2026-11-14T18:00:00Z'), now), isTrue);
    expect(AppDates.isSameVietnamDay(DateTime.parse('2026-11-14T16:59:59Z'), now), isFalse);
    expect(AppDates.isSameVietnamDay(DateTime.parse('2026-11-15T17:00:00Z'), now), isFalse);
  });

  test('Retailer 7/30 day boundaries use Vietnam dates and preserve inclusive ranges', () {
    final now = DateTime.parse('2027-01-15T18:00:00Z'); // Jan 16 in Vietnam.
    expect(AppDates.vietnamDaysBetween(DateTime.parse('2027-01-08T17:00:00Z'), now), 7);
    expect(AppDates.vietnamDaysBetween(DateTime.parse('2027-01-08T16:59:59Z'), now), 8);
    expect(AppDates.vietnamDaysBetween(DateTime.parse('2026-12-16T17:00:00Z'), now), 30);
    expect(AppDates.vietnamDaysBetween(DateTime.parse('2026-12-16T16:59:59Z'), now), 31);
  });

  test('existing DateOnly expiry formatting remains unchanged', () {
    expect(AppDates.date(DateTime.parse('2026-11-15')), '15/11/2026');
    expect(AppDates.daysBetween(DateTime(2026, 11, 15), DateTime(2026, 11, 16)), 1);
  });
}
