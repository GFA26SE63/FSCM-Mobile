import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/enums.dart';

void main() {
  test('pending prepaid orders retain a payment entry after reopening', () {
    final pending = Order.fromJson({
      'status': 'PaymentPending',
      'payment': {'method': 'Prepaid', 'status': 'Unpaid'},
    });
    expect(pending.canPayOnline, isTrue);
    expect(
        Order.fromJson({
          'status': 'PaymentPending',
          'payment': {'method': 'Prepaid', 'status': 'Paid'},
        }).canPayOnline,
        isFalse);
    expect(
        Order.fromJson({
          'status': 'Cancelled',
          'payment': {'method': 'Prepaid', 'status': 'Cancelled'},
        }).canPayOnline,
        isFalse);
  });

  test('reads nested payment and server history from order detail', () {
    final order = Order.fromJson({
      'paymentMethod': 'Credit',
      'creditTermDays': 14,
      'payment': {
        'method': 'Credit',
        'status': 'Paid',
        'outstandingAmount': 0,
        'dueDate': '2026-11-19',
      },
      'history': [
        {
          'changedAt': '2026-11-05T16:08:15Z',
          'toStatus': 'Delivered',
          'reason': 'Đã nhận đủ hàng',
        },
      ],
    });
    expect(order.payment, PaymentMethod.credit);
    expect(order.paid, isTrue);
    expect(order.creditTerm, 14);
    expect(order.dueDate, DateTime(2026, 11, 19));
    expect(order.timeline.single.label, 'Đã nhận đủ hàng');
    expect(order.timeline.single.time, isNotNull);
  });

  test('preserves local cached payment and prioritizes server unpaid state',
      () {
    final cached = Order.fromJson({'payment': 'Credit', 'paid': true});
    expect(cached.payment, PaymentMethod.credit);
    expect(cached.paid, isTrue);
    final unpaid = Order.fromJson({
      'paymentMethod': 'Prepaid',
      'paid': true,
      'payment': {'method': 'Prepaid', 'status': 'Unpaid'},
    });
    expect(unpaid.payment, PaymentMethod.prepaid);
    expect(unpaid.paid, isFalse);
  });
}
