import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';

void main() {
  group('Money.format', () {
    test('uses dots as thousands separators and the đ suffix', () {
      expect(Money.format(0), '0đ');
      expect(Money.format(950), '950đ');
      expect(Money.format(1000), '1.000đ');
      expect(Money.format(35000000), '35.000.000đ');
      expect(Money.format(1234567), '1.234.567đ');
    });

    test('negative amounts and rounding', () {
      expect(Money.format(-720000), '−720.000đ');
      expect(Money.format(1999.6), '2.000đ');
    });

    test('minus shows discounts, zero stays plain', () {
      expect(Money.minus(720000), '−720.000đ');
      expect(Money.minus(0), '0đ');
    });
  });

  group('Money.short', () {
    test('millions and billions use a decimal comma', () {
      expect(Money.short(245700000), '245,7 tr');
      expect(Money.short(1200000000), '1,2 tỷ');
      expect(Money.short(3000000), '3 tr');
      expect(Money.short(45000), '45 k');
      expect(Money.short(500), '500');
    });
  });

  group('Money.parse', () {
    test('ignores separators and symbols', () {
      expect(Money.parse('35.000.000'), 35000000);
      expect(Money.parse('35000000đ'), 35000000);
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
    });
  });

  group('OrderLimits.maxQty', () {
    test('available minus buffer, rounded down to a multiple of 10', () {
      expect(OrderLimits.maxQty(120), 100);
      expect(OrderLimits.maxQty(129), 100);
      expect(OrderLimits.maxQty(130), 110);
      expect(OrderLimits.maxQty(35), 10);
    });

    test('never negative', () {
      expect(OrderLimits.maxQty(20), 0);
      expect(OrderLimits.maxQty(5), 0);
      expect(OrderLimits.maxQty(0), 0);
    });
  });
}
