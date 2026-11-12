import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/features/common/profile/widgets/profile_identity_card.dart';

Map<String, dynamic> profileJson(String role) => <String, dynamic>{
      'id': 'user',
      'fullName': 'Nguyễn Văn An',
      'email': 'account@example.com',
      'role': role,
      if (role == 'Retailer') 'retailerCode': '10004127',
      'scope': <String, dynamic>{
        'retailerIds': ['retailer'],
        'warehouseIds': ['w1', 'w2'],
        'salesGroupIds': ['g1', 'g2'],
        'regionIds': ['r1', 'r2'],
      },
      'scopeLabels': <String, dynamic>{
        'retailers': [
          {'id': 'retailer', 'code': '10004127', 'name': 'Cửa hàng An Phú'},
        ],
        'warehouses': [
          {'id': 'w1', 'code': 'WH-01', 'name': 'Kho Thủ Đức'},
          {'id': 'w2', 'code': 'WH-02', 'name': 'Kho Quận 12'},
        ],
        'salesGroups': [
          {'id': 'g1', 'code': 'G1', 'name': 'Nhóm Một'},
          {'id': 'g2', 'code': 'G2', 'name': 'Nhóm Hai'},
        ],
        'regions': [
          {'id': 'r1', 'code': 'R1', 'name': 'Vùng Đông'},
          {'id': 'r2', 'code': 'R2', 'name': 'Vùng Tây'},
        ],
      },
    };

void main() {
  for (final role in ['Retailer', 'Sales', 'WarehouseKeeper']) {
    testWidgets('$role profile shows all role details on a small screen',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child:
                ProfileIdentityCard(user: AppUser.fromJson(profileJson(role))),
          ),
        ),
      ));
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Email: account@example.com'), findsOneWidget);
      expect(find.textContaining('SĐT:'), findsNothing);
      if (role == 'Retailer') {
        expect(find.text('Cửa hàng An Phú · Mã 10004127'), findsOneWidget);
        expect(find.text('Kho phụ trách'), findsNothing);
      } else if (role == 'Sales') {
        for (final text in [
          'Nhóm Một · Mã G1',
          'Nhóm Hai · Mã G2',
          'Vùng Đông · Mã R1',
          'Vùng Tây · Mã R2',
        ]) {
          expect(find.text(text), findsOneWidget);
        }
        expect(find.text('Điểm bán'), findsNothing);
      } else {
        expect(find.text('Kho Thủ Đức · Mã WH-01'), findsOneWidget);
        expect(find.text('Kho Quận 12 · Mã WH-02'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('real phone is shown but a legacy duplicated email is not',
      (tester) async {
    for (final phone in ['0901234567', 'account@example.com']) {
      final json = profileJson('Retailer')..['phone'] = phone;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProfileIdentityCard(user: AppUser.fromJson(json))),
      ));
      expect(find.text('Email: account@example.com'), findsOneWidget);
      expect(find.text('SĐT: 0901234567'),
          phone.startsWith('090') ? findsOneWidget : findsNothing);
      expect(find.text('SĐT: account@example.com'), findsNothing);
    }
  });
}
