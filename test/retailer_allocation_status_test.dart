import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/utils/status_labels.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/features/retailer/orders/rt_order_detail_screen.dart';

/// M-27: "Kết quả" on the Retailer order detail. The Backend sends the
/// allocation RUN status in `allocationResult` (Processing | Succeeded |
/// OutOfStock | Conflict | TechnicalFailed), null while no run exists.
const _user = AppUser(
    id: 'user-1',
    fullName: 'Retailer',
    phone: '',
    role: UserRole.retailer,
    retailerCode: '1001');

Order _order(String state, String? result) => Order.fromJson(<String, dynamic>{
      'id': 'order-1',
      'orderCode': 'DH-001057',
      'retailerId': 'retailer-1',
      'status': state == 'Allocating' ? 'Allocating' : 'Quoted',
      'allocationState': state,
      'allocationResult': result,
    });

void main() {
  test('every Backend run status has its own truthful text', () {
    expect(allocationResultLabel('Processing'), 'Đang xử lý phân bổ');
    expect(allocationResultLabel('Succeeded'), 'Phân bổ thành công');
    expect(allocationResultLabel('OutOfStock'), 'Không đủ hàng để phân bổ');
    expect(allocationResultLabel('Conflict'), 'Xung đột khi phân bổ');
    expect(
        allocationResultLabel('TechnicalFailed'), 'Phân bổ gặp lỗi hệ thống');
    // Missing result: a placeholder, neither success nor failure.
    expect(allocationResultLabel(null), 'Chưa có kết quả phân bổ');
    expect(allocationResultLabel('  '), 'Chưa có kết quả phân bổ');
    // Unknown future value: safe fallback, never mistaken for success.
    expect(allocationResultLabel('SomethingNew'), unknownStatusLabel);
    expect(allocationResultLabel('SomethingNew'),
        isNot(allocationResultLabel('Succeeded')));
    // State and result stay separate concepts with their own value sets.
    expect(allocationStateLabel('Allocated'), 'Đã phân bổ hàng');
    expect(allocationStateLabel('Succeeded'), unknownStatusLabel);
    expect(allocationResultLabel('Allocated'), unknownStatusLabel);
  });

  const cases = <(String, String?, String, String)>[
    ('Allocating', null, 'Đang phân bổ hàng', 'Chưa có kết quả phân bổ'),
    ('Allocating', 'Processing', 'Đang phân bổ hàng', 'Đang xử lý phân bổ'),
    ('Allocated', 'Succeeded', 'Đã phân bổ hàng', 'Phân bổ thành công'),
    (
      'Failed',
      'OutOfStock',
      'Phân bổ không thành công',
      'Không đủ hàng để phân bổ'
    ),
    ('Failed', 'Conflict', 'Phân bổ không thành công', 'Xung đột khi phân bổ'),
    (
      'Failed',
      'TechnicalFailed',
      'Phân bổ không thành công',
      'Phân bổ gặp lỗi hệ thống'
    ),
    ('Allocated', 'FutureValue', 'Đã phân bổ hàng', 'Chưa rõ trạng thái'),
  ];

  for (final width in <double>[360, 390]) {
    for (final scale in <double>[1.0, 1.3, 1.6]) {
      testWidgets(
          'order detail shows state and result (${width.toInt()}dp '
          'x$scale)', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 3000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final c in cases) {
          final order = _order(c.$1, c.$2);
          await tester.pumpWidget(ProviderScope(
            key: UniqueKey(),
            overrides: [
              currentUserProvider.overrideWithValue(_user),
              orderDetailProvider('DH-001057')
                  .overrideWith((ref) async => order),
              deliveryShipmentsProvider('order-1')
                  .overrideWith((ref) async => []),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: const RtOrderDetailScreen(code: 'DH-001057'),
            ),
          ));
          await tester.pumpAndSettle();
          expect(find.text(c.$3), findsOneWidget, reason: '${c.$1}/${c.$2}');
          expect(find.text(c.$4), findsOneWidget, reason: '${c.$1}/${c.$2}');
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
