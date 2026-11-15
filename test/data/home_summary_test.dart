import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/repositories/home_summary_repository.dart';

Receivable _receivable(String status, int outstanding, DateTime due) =>
    Receivable.fromJson(<String, dynamic>{
      'id': 'r-$status-$outstanding',
      'orderId': 'o',
      'paymentId': 'p',
      'orderCode': 'SO-1',
      'retailerCode': '10004127',
      'retailerName': 'Shop',
      'status': status,
      'amount': outstanding,
      'adjustedAmount': outstanding,
      'outstandingAmount': outstanding,
      'dueDate': due.toIso8601String(),
      'method': 'Credit',
    });

void main() {
  final now = DateTime(2026, 11, 14, 10);

  test('retailer todo splits overdue and due-soon credit, ignoring paid rows',
      () {
    final todo = RetailerTodo.from(
      quotes: 2,
      payments: 0,
      deliveries: 1,
      now: now,
      receivables: <Receivable>[
        _receivable('Overdue', 500000, DateTime(2026, 11, 1)),
        _receivable('Unpaid', 300000, DateTime(2026, 11, 18)),
        _receivable('Unpaid', 900000, DateTime(2026, 12, 30)),
        _receivable('Paid', 0, DateTime(2026, 11, 15)),
      ],
      points: 120,
    );
    expect(todo.quotesToConfirm, 2);
    expect(todo.deliveriesToReceive, 1);
    expect(todo.overdueCount, 1);
    expect(todo.overdueAmount, 500000);
    expect(todo.dueSoonCount, 1);
    expect(todo.dueSoonAmount, 300000);
    expect(todo.loyaltyPoints, 120);
    expect(todo.hasAction, isTrue);
  });

  test('nothing to do when there are no open items', () {
    final todo = RetailerTodo.from(
        quotes: 0,
        payments: 0,
        deliveries: 0,
        receivables: const <Receivable>[],
        now: now);
    expect(todo.hasAction, isFalse);
    expect(todo.loyaltyPoints, isNull);
  });
}
