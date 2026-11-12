import 'package:flutter_test/flutter_test.dart';

import 'package:fscm_mobile/core/auth/session.dart';

void main() {
  Map<String, dynamic> retailerUser() => <String, dynamic>{
        'id': 'retailer-user',
        'fullName': 'An Phú',
        'role': 'Retailer',
        'retailerCode': 'ACCOUNT-CODE',
        'retailerName': 'An Phú',
        'scope': <String, dynamic>{
          'retailerIds': <String>['owned-retailer'],
        },
        'scopeLabels': <String, dynamic>{
          'retailers': <Map<String, dynamic>>[
            {'id': 'owned-retailer', 'code': '10004127', 'name': 'An Phú'},
          ],
        },
      };

  test('explicit retailer code and name take precedence over scope labels', () {
    final user = AppUser.fromJson(retailerUser());
    expect(user.retailerCode, 'ACCOUNT-CODE');
    expect(user.retailerName, 'An Phú');
    expect(user.scopeText, 'Mã ACCOUNT-CODE');
    final restored = AppUser.fromJson(user.toJson());
    expect(restored.retailerCode, 'ACCOUNT-CODE');
    expect(restored.retailerIds, ['owned-retailer']);
  });

  test('missing labels do not overwrite an explicit account retailer code', () {
    final json = retailerUser();
    json['scopeLabels'] = <String, dynamic>{'retailers': <dynamic>[]};
    expect(AppUser.fromJson(json).retailerCode, 'ACCOUNT-CODE');
  });

  test('Sales assigned retailers are not treated as the Sales own retailer',
      () {
    final json = retailerUser()
      ..['role'] = 'Sales'
      ..remove('retailerCode');
    expect(AppUser.fromJson(json).retailerCode, isNull);
  });

  test('legacy cached retailer code survives until server scope is loaded', () {
    final json = retailerUser()..remove('scopeLabels');
    final restored = AppUser.fromJson(AppUser.fromJson(json).toJson());
    expect(AppUser.fromJson(json).retailerCode, 'ACCOUNT-CODE');
    expect(restored.retailerCode, 'ACCOUNT-CODE');
  });

  test('Retailer scope fallback from develop survives session persistence', () {
    final json = retailerUser()
      ..remove('retailerCode')
      ..remove('retailerName');
    // The server returns labels for the user's scope. Match develop's
    // first-label fallback when no explicit account code/name is supplied.
    final user = AppUser.fromJson(json);
    expect(user.retailerCode, '10004127');
    expect(user.retailerName, 'An Phú');
    final restored = AppUser.fromJson(user.toJson());
    expect(restored.retailerCode, '10004127');
    expect(restored.retailerName, 'An Phú');
  });

  test('blank flat retailer values use develop scope fallback', () {
    final json = retailerUser()
      ..['retailerCode'] = ''
      ..['retailerName'] = '';
    final user = AppUser.fromJson(json);
    expect(user.retailerCode, '10004127');
    expect(user.retailerName, 'An Phú');
  });

  test('authentication session preserves access and refresh tokens', () {
    final session = Session.fromJson(<String, dynamic>{
      'accessToken': 'access-token',
      'accessTokenExpiresAt': '2026-10-31T01:00:00Z',
      'refreshToken': 'refresh-token',
      'refreshTokenExpiresAt': '2026-11-30T00:00:00Z',
      'user': <String, dynamic>{
        'id': 'user-id',
        'fullName': 'Điểm bán An Phú',
        'email': 'retailer@example.com',
        'role': 'Retailer',
      },
    });

    final persisted = session.toJson();
    expect(persisted['accessToken'], 'access-token');
    expect(persisted['refreshToken'], 'refresh-token');
    expect(persisted['refreshTokenExpiresAt'], '2026-11-30T00:00:00.000Z');
  });

  test('all assigned warehouses survive mapping and session persistence', () {
    final user = AppUser.fromJson(<String, dynamic>{
      'id': 'keeper',
      'role': 'WarehouseKeeper',
      'email': 'keeper@example.com',
      'scope': <String, dynamic>{
        'warehouseIds': ['w1', 'w2']
      },
      'scopeLabels': <String, dynamic>{
        'warehouses': [
          {'id': 'w1', 'code': 'WH-01', 'name': 'Kho Thủ Đức'},
          {'id': 'w2', 'code': 'WH-02', 'name': 'Kho Quận 12'},
        ],
      },
    });
    final restored = AppUser.fromJson(user.toJson());
    expect(restored.warehouseIds, ['w1', 'w2']);
    expect(restored.warehouseLabels.map((label) => label.name),
        ['Kho Thủ Đức', 'Kho Quận 12']);
    expect(restored.warehouseCode, 'WH-01');
    expect(restored.phone, isEmpty);
  });

  test('all Sales groups and regions survive session persistence', () {
    final user = AppUser.fromJson(<String, dynamic>{
      'id': 'sales',
      'role': 'Sales',
      'scope': <String, dynamic>{
        'regionIds': ['r1', 'r2'],
        'salesGroupIds': ['g1', 'g2'],
      },
      'scopeLabels': <String, dynamic>{
        'regions': [
          {'id': 'r1', 'code': 'R1', 'name': 'Vùng Đông'},
          {'id': 'r2', 'code': 'R2', 'name': 'Vùng Tây'},
        ],
        'salesGroups': [
          {'id': 'g1', 'code': 'G1', 'name': 'Nhóm Một'},
          {'id': 'g2', 'code': 'G2', 'name': 'Nhóm Hai'},
        ],
      },
    });
    final restored = AppUser.fromJson(user.toJson());
    expect(restored.salesGroupLabels.map((label) => label.code), ['G1', 'G2']);
    expect(restored.regionLabels.map((label) => label.code), ['R1', 'R2']);
  });
}
