import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmcg/app.dart';

void main() {
  testWidgets('Sales user can sign in and open the order flow', (tester) async {
    await tester.pumpWidget(const FscmApp());

    expect(find.text('FSCM Sales'), findsOneWidget);
    expect(
      find.text('Đặt hàng cho điểm bán, kể cả khi mất mạng.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, Nguyễn Văn An'), findsOneWidget);
    expect(find.text('Tạo đơn hàng mới'), findsOneWidget);

    await tester.tap(find.byKey(const Key('newOrderButton')));
    await tester.pumpAndSettle();

    expect(find.text('Chọn điểm bán'), findsOneWidget);
    expect(find.text('Tạp hóa Minh Châu'), findsOneWidget);
  });

  testWidgets('Retailer can select its experience and sign in', (tester) async {
    await tester.pumpWidget(const FscmApp());

    await tester.ensureVisible(find.text('Retailer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retailer'));
    await tester.pumpAndSettle();

    expect(find.text('FSCM Retailer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('retailerLoginButton')));
    await tester.pumpAndSettle();

    expect(find.text('Tạp hóa Minh Châu'), findsWidgets);
    expect(find.textContaining('Công nợ còn phải trả'), findsOneWidget);
  });
}
