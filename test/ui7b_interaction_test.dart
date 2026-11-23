import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/app/app.dart';
import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/focus.dart';
import 'package:fscm_mobile/data/models/label_detail.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/warehouse/labels/label_detail_screen.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';
import 'package:go_router/go_router.dart';

/// UI.7B regression tests: focus release (M-02), timeline order (M-06),
/// Back after "scan another" (M-12), snack placement above a body bar (M-18).
void main() {
  group('M-02 focus release', () {
    Future<void> pumpSearch(WidgetTester tester) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                appBar: AppBar(title: const Text('Tiêu đề')),
                body: const TextField(onTapOutside: releaseFocus))));

    testWidgets('tapping outside the search field releases focus and keyboard',
        (tester) async {
      await pumpSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.text('Tiêu đề'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus,
          isNot(isA<EditableTextState>()));
    });

    testWidgets('a route change releases focus; typed text is kept',
        (tester) async {
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (c, s) => Scaffold(
                    body: Column(children: [
                  const TextField(),
                  TextButton(
                      onPressed: () => c.push('/next'),
                      child: const Text('đi tiếp')),
                ]))),
        GoRoute(
            path: '/next',
            builder: (c, s) =>
                Scaffold(appBar: AppBar(title: const Text('Trang kế')))),
      ]);
      // Same hook as routerProvider.
      router.routerDelegate.addListener(releaseFocus);
      addTearDown(() {
        router.routerDelegate.removeListener(releaseFocus);
        router.dispose();
      });
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.enterText(find.byType(TextField), 'sữa');
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.text('đi tiếp'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);

      router.pop();
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse); // not restored
      expect(find.text('sữa'), findsOneWidget); // text preserved
    });
  });

  group('M-06 timeline', () {
    for (final scale in <double>[1.0, 1.6]) {
      testWidgets('shows the newest step first ($scale x)', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 720);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final entries = <TimelineEntry>[
          TimelineEntry(time: DateTime(2026, 11, 1, 8), label: 'Tạo đơn'),
          TimelineEntry(time: DateTime(2026, 11, 2, 9), label: 'Đã báo giá'),
          TimelineEntry(time: DateTime(2026, 11, 3, 10), label: 'Đã giao'),
        ];
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(child: TimelineList(entries)))));
        double y(String t) => tester.getTopLeft(find.text(t)).dy;
        expect(y('Đã giao'), lessThan(y('Đã báo giá')));
        expect(y('Đã báo giá'), lessThan(y('Tạo đơn')));
        // The source list is not mutated.
        expect(entries.first.label, 'Tạo đơn');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('M-12 label detail keeps a way back', () {
    GoRouter build(String initial) =>
        GoRouter(initialLocation: initial, routes: [
          GoRoute(
              path: '/',
              builder: (c, s) => Scaffold(
                  appBar: AppBar(title: const Text('Gốc')),
                  body: TextButton(
                      onPressed: () => c.push('/wk/label-lookup'),
                      child: const Text('mở tra cứu')))),
          GoRoute(
              path: '/wk/label-lookup',
              builder: (c, s) => Scaffold(
                  appBar: AppBar(title: const Text('Tra cứu tem')),
                  body: TextButton(
                      onPressed: () => c.push('/wk/label/TEM-000001'),
                      child: const Text('xem tem')))),
          GoRoute(
              path: '/wk/label/:code',
              builder: (c, s) =>
                  LabelDetailScreen(code: s.pathParameters['code']!)),
        ]);

    Future<void> pump(WidgetTester tester, GoRouter router) async {
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          labelDetailProvider('TEM-000001').overrideWith((ref) =>
              Future<LabelDetail>.error(const ApiException(
                  kind: ApiErrorKind.notFound, message: 'Không có tem'))),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('opened from the lookup: "scan another" pops back to it',
        (tester) async {
      final router = build('/');
      await pump(tester, router);
      await tester.tap(find.text('mở tra cứu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('xem tem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quét hoặc nhập mã khác'));
      await tester.pumpAndSettle();

      expect(find.text('Tra cứu tem'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget); // origin still below
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Gốc'), findsOneWidget);
    });

    testWidgets('opened from a link (no previous route): lookup has a Back',
        (tester) async {
      final router = build('/wk/label/TEM-000001');
      await pump(tester, router);
      expect(find.byType(BackButton), findsNothing); // nothing to go back to
      await tester.tap(find.text('Quét hoặc nhập mã khác'));
      await tester.pumpAndSettle();

      expect(find.text('Tra cứu tem'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  group('M-18 feedback above a bar inside the page body', () {
    testWidgets('the message sits above the bar and never covers its action',
        (tester) async {
      final key = GlobalKey<ScaffoldMessengerState>();
      final barKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: key,
        home: Scaffold(
            body: Column(children: [
          const Expanded(child: SizedBox()),
          SafeArea(
              key: barKey,
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                      onPressed: () {},
                      child: const Text('Xem giỏ & đặt hàng')))),
        ])),
      ));
      final feedback = RootFeedbackController(messengerKey: key);
      final barHeight = barKey.currentContext!.size!.height;

      feedback.showUndo('Đã bỏ Sữa khỏi giỏ.',
          onUndo: () {}, bottomClearance: barHeight);
      await tester.pumpAndSettle();
      final snack = tester.getRect(find.text('Đã bỏ Sữa khỏi giỏ.'));
      final cta = tester.getRect(find.text('Xem giỏ & đặt hàng'));
      expect(snack.bottom, lessThanOrEqualTo(cta.top));

      // A second removal replaces the first in the same place (no stacking).
      feedback.showUndo('Đã bỏ Bột giặt khỏi giỏ.',
          onUndo: () {}, bottomClearance: barHeight);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.getRect(find.text('Đã bỏ Bột giặt khỏi giỏ.')).bottom,
          closeTo(snack.bottom, 0.5));
    });
  });
}
