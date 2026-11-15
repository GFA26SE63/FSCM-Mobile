import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/app/app.dart';

Future<RootFeedbackController> _pumpFeedbackHost(WidgetTester tester) async {
  final key = GlobalKey<ScaffoldMessengerState>();
  await tester.pumpWidget(MaterialApp(
    scaffoldMessengerKey: key,
    home: const Scaffold(body: SizedBox()),
  ));
  return RootFeedbackController(messengerKey: key);
}

void main() {
  testWidgets('deduplicates repeated non-critical feedback', (tester) async {
    final feedback = await _pumpFeedbackHost(tester);

    feedback.show('Đã lưu thay đổi.');
    feedback.show('Đã lưu thay đổi.');
    await tester.pump();

    expect(find.text('Đã lưu thay đổi.'), findsOneWidget);
  });

  testWidgets('an error preempts success and preserves later errors',
      (tester) async {
    final feedback = await _pumpFeedbackHost(tester);

    feedback.show('Đã cập nhật.');
    await tester.pump();
    feedback.show('Không thể lưu.', error: true);
    feedback.show('Mất kết nối.', error: true);
    await tester.pumpAndSettle();

    expect(find.text('Không thể lưu.'), findsOneWidget);
    expect(find.text('Đã cập nhật.'), findsNothing);

    final messenger = tester.state<ScaffoldMessengerState>(
      find.byType(ScaffoldMessenger),
    );
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    expect(find.text('Mất kết nối.'), findsOneWidget);
  });
}
