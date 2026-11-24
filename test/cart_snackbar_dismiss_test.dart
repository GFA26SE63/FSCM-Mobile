import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/app.dart';

/// M-26: the "Đã bỏ … khỏi giỏ" undo message must dismiss itself. Flutter keeps
/// a SnackBar that has an action on screen until dismissed unless
/// `persist: false`, which ignores `duration` otherwise.
class _Host {
  _Host(this.key, this.feedback, this.bar);
  final GlobalKey<ScaffoldMessengerState> key;
  final RootFeedbackController feedback;
  final GlobalKey bar;
}

Future<_Host> _pump(WidgetTester tester,
    {double width = 390, double scale = 1.0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 720);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey<ScaffoldMessengerState>();
  final bar = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    scaffoldMessengerKey: key,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
        body: Column(children: [
      const Expanded(child: SizedBox()),
      SafeArea(
          key: bar,
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: () {}, child: const Text('Xem giỏ & đặt hàng')))),
    ])),
  ));
  return _Host(key, RootFeedbackController(messengerKey: key), bar);
}

/// Fake time: the SnackBar's own timer starts after its entrance animation and
/// the next frame, so allow up to 8 s of fake time (not real waiting).
Future<void> _waitGone(WidgetTester tester) async {
  for (var i = 0; i < 16 && find.byType(SnackBar).evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsNothing);
}

void main() {
  for (final width in <double>[360, 390]) {
    for (final scale in <double>[1.0, 1.6]) {
      final tag = '${width.toInt()}dp x$scale';

      testWidgets('undo message disappears by itself after ~4 s ($tag)',
          (tester) async {
        final h = await _pump(tester, width: width, scale: scale);
        var undone = 0;
        h.feedback.showUndo('Đã bỏ Sữa khỏi giỏ.',
            onUndo: () => undone++,
            bottomClearance: h.bar.currentContext!.size!.height);
        await tester.pump();
        expect(find.text('Đã bỏ Sữa khỏi giỏ.'), findsOneWidget);

        await tester.pump(const Duration(seconds: 3));
        expect(find.text('Đã bỏ Sữa khỏi giỏ.'), findsOneWidget); // still there
        await _waitGone(tester);
        expect(undone, 0); // doing nothing leaves the item removed

        // The queue advanced: the next message can appear and also goes away.
        h.feedback.showUndo('Đã bỏ Bột giặt khỏi giỏ.', onUndo: () {});
        await tester.pump();
        expect(find.text('Đã bỏ Bột giặt khỏi giỏ.'), findsOneWidget);
        await _waitGone(tester);
      });

      testWidgets(
          'undo runs once and dismisses; message stays above the CTA '
          '($tag)', (tester) async {
        final h = await _pump(tester, width: width, scale: scale);
        var undone = 0;
        h.feedback.showUndo('Đã bỏ Sữa khỏi giỏ.',
            onUndo: () => undone++,
            bottomClearance: h.bar.currentContext!.size!.height);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        final text = tester.getRect(find.text('Đã bỏ Sữa khỏi giỏ.'));
        final cta = tester.getRect(find.text('Xem giỏ & đặt hàng'));
        expect(text.bottom, lessThanOrEqualTo(cta.top));

        await tester.tap(find.text('Hoàn tác'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton)); // CTA is not blocked
        expect(undone, 1);
        expect(find.byType(SnackBar), findsNothing);
        await tester.pump(const Duration(seconds: 8));
        expect(undone, 1); // never twice
      });

      testWidgets(
          'rapid removals show one message, never a growing stack '
          '($tag)', (tester) async {
        final h = await _pump(tester, width: width, scale: scale);
        for (var i = 0; i < 5; i++) {
          h.feedback.showUndo('Đã bỏ SP $i khỏi giỏ.', onUndo: () {});
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Đã bỏ SP 4 khỏi giỏ.'), findsOneWidget);
        // Rebuilds do not restart the timer: 4 s after the LAST show it goes.
        await _waitGone(tester);
      });
    }
  }

  testWidgets('leaving the screen hides a pending undo message',
      (tester) async {
    final h = await _pump(tester);
    h.feedback.showUndo('Đã bỏ Sữa khỏi giỏ.', onUndo: () {});
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    h.feedback.hideUndo();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    // An error message is not an undo message: hideUndo leaves it alone.
    h.feedback.show('Không thể lưu.', error: true);
    await tester.pump();
    h.feedback.hideUndo();
    await tester.pump();
    expect(find.text('Không thể lưu.'), findsOneWidget);
  });
}
