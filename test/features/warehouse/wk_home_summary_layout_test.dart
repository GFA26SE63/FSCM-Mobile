import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/app/theme.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_api.dart';
import 'package:fscm_mobile/features/warehouse/home/wk_home_screen.dart';
import 'package:fscm_mobile/features/warehouse/widgets/wk_widgets.dart';

// MOB-05: the three summary cards share the row height; the two right labels
// wrap, so the "Cần xử lý" value used to sit higher than the other values.

WarehouseWork _doc(String id, Map<String, dynamic> extra) => WarehouseWork({
      'document': {'id': id, 'code': id, 'version': 1, ...extra},
      'lines': <Object>[],
      'cartons': <Object>[],
    });

final _docs = [
  // 2 pending in scope.
  _doc('p1', {'kind': 'Issue', 'reason': 'Order', 'status': 'Open', 'warehouseId': 'A'}),
  _doc('p2', {'kind': 'Receipt', 'reason': 'Factory', 'status': 'Open', 'warehouseId': 'A'}),
  // 1 incoming transfer.
  _doc('i1', {
    'kind': 'Issue', 'reason': 'Transfer', 'status': 'Posted',
    'warehouseId': 'X', 'destinationWarehouseId': 'A'
  }),
];

Future<void> _pump(WidgetTester tester, double width, double scale) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => const AppUser(
            id: 'k',
            fullName: 'Thủ kho',
            phone: '',
            role: UserRole.warehouseKeeper,
            warehouseIds: ['A'])),
        warehouseDocumentsProvider.overrideWith((ref) async => _docs),
        factoryArrivalsProvider.overrideWith((ref) async => [
              for (var i = 0; i < 128; i++) <String, dynamic>{'palletCode': 'P$i'}
            ]),
      ],
      child: MaterialApp(
          theme: buildAppTheme(),
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const WkHomeScreen())));
  await tester.pumpAndSettle();
}

Rect _card(WidgetTester tester, String label) => tester.getRect(find.ancestor(
    of: find.text(label), matching: find.byType(WkStatCard)));

Rect _value(WidgetTester tester, String label, String value) =>
    tester.getRect(find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(WkStatCard)),
        matching: find.text(value)));

void main() {
  for (final width in [320.0, 360.0, 390.0, 411.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('summary aligned at ${width}dp × $scale', (tester) async {
        await _pump(tester, width, scale);
        expect(tester.takeException(), isNull); // no RenderFlex overflow

        const cards = [
          ('Cần xử lý', '2'),
          ('Pallet chờ nhận', '128'),
          ('Chuyến đang đến', '1'),
        ];
        final rects = [for (final (l, _) in cards) _card(tester, l)];
        // Same row, same height.
        for (final r in rects) {
          expect(r.top, moreOrLessEquals(rects.first.top, epsilon: 0.5));
          expect(r.height, moreOrLessEquals(rects.first.height, epsilon: 0.5));
        }
        // Values share one bottom line and stay inside their card (no clip).
        final values = [for (final (l, v) in cards) _value(tester, l, v)];
        for (var i = 0; i < cards.length; i++) {
          expect(values[i].bottom,
              moreOrLessEquals(values.first.bottom, epsilon: 0.5));
          expect(values[i].left, greaterThanOrEqualTo(rects[i].left));
          expect(values[i].right, lessThanOrEqualTo(rects[i].right));
          expect(values[i].bottom, lessThanOrEqualTo(rects[i].bottom));
          // Label above its own value.
          final label = tester.getRect(find.text(cards[i].$1));
          expect(label.bottom, lessThanOrEqualTo(values[i].top + 0.5));
        }
      });
    }
  }
}
