import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/data/pricing/order_limits.dart';

void main() {
  group('Money.format', () {
    test('uses dots as thousands separators and the VND suffix', () {
      expect(Money.format(0), '0 VND');
      expect(Money.format(950), '950 VND');
      expect(Money.format(1000), '1.000 VND');
      expect(Money.format(35000000), '35.000.000 VND');
      expect(Money.format(1234567), '1.234.567 VND');
    });

    test('negative amounts and rounding', () {
      expect(Money.format(-720000), '−720.000 VND');
      expect(Money.format(1999.6), '2.000 VND');
    });

    test('minus shows discounts, zero stays plain', () {
      expect(Money.minus(720000), '−720.000 VND');
      expect(Money.minus(0), '0 VND');
    });
  });

  group('Money.short', () {
    test('millions and billions use a decimal comma', () {
      expect(Money.short(245700000), '245,7 tr VND');
      expect(Money.short(1200000000), '1,2 tỷ VND');
      expect(Money.short(3000000), '3 tr VND');
      expect(Money.short(45000), '45 k VND');
      expect(Money.short(500), '500 VND');
    });
  });

  group('Money.parse', () {
    test('ignores separators and symbols', () {
      expect(Money.parse('35.000.000'), 35000000);
      expect(Money.parse('35000000 VND'), 35000000);
      expect(Money.parse('35000000đ'), 35000000);
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
    });
  });

  group('OrderLimits.maxQty', () {
    test('does not subtract a buffer; rounds down only for the existing step',
        () {
      expect(OrderLimits.maxQty(10), 10);
      expect(OrderLimits.maxQty(120), 120);
      expect(OrderLimits.maxQty(129), 129);
      expect(OrderLimits.maxQty(130), 130);
      expect(OrderLimits.maxQty(35), 35);
      expect(OrderLimits.maxQty(35, step: 10), 30);
      expect(OrderLimits.maxQty(6, step: 2), 6);
    });

    test('never negative', () {
      expect(OrderLimits.maxQty(20), 20);
      expect(OrderLimits.maxQty(5), 5);
      expect(OrderLimits.maxQty(0), 0);
    });
  });
}
