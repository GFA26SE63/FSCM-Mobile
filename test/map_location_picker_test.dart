import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/shared/widgets/map_location_picker.dart';

void main() {
  testWidgets('opening picker does not select the default map center', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: MapLocationPicker(address: 'Địa chỉ nhập tay'),
    )));
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dùng vị trí này')).onPressed, isNull);
    expect(find.textContaining('Tọa độ:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening and confirming preserves existing coordinates and reference', (tester) async {
    MapPlace? result;
    const existing = MapPlace(latitude: 10.77, longitude: 106.7,
        address: 'Địa chỉ cũ', providerPlaceId: 'ref-1');
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () async {
          result = await Navigator.of(context).push<MapPlace>(MaterialPageRoute(
            builder: (_) => const MapLocationPicker(address: 'Địa chỉ cũ', initial: existing),
          ));
        }, child: const Text('Mở bản đồ'),
      ))),
    )));
    await tester.tap(find.text('Mở bản đồ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10.770000, 106.700000'), findsOneWidget);
    await tester.tap(find.text('Dùng vị trí này'));
    await tester.pumpAndSettle();
    expect(result?.latitude, existing.latitude);
    expect(result?.longitude, existing.longitude);
    expect(result?.providerPlaceId, 'ref-1');
    expect(tester.takeException(), isNull);
  });
}
