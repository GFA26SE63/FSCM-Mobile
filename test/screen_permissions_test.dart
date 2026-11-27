import 'package:fscm_mobile/app/router.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/screen_permissions.dart';

void main() {
  AppUser user(List<String> grants) => AppUser.fromJson({
        'id': 'user',
        'fullName': 'User',
        'phone': '0900000000',
        'role': 'Sales',
        'permissions': grants,
      });

  test(
      'delegated mobile screen works across profiles and revocation redirects safely',
      () {
    final delegated = AppUser.fromJson({
      'id': 'operator',
      'role': 'Operator',
      'permissions': ['mobile-wk-picking'],
    });
    expect(canAccessMobilePath(delegated, '/wk/home'), isTrue);
    expect(firstGrantedMobilePath(delegated), '/wk/home');
    expect(
        redirectFor(
            status: AuthStatus.authenticated,
            role: delegated.role,
            user: delegated,
            location: '/wk/home'),
        isNull);
    final revoked =
        AppUser.fromJson({...delegated.toJson(), 'permissions': <String>[]});
    expect(
        redirectFor(
            status: AuthStatus.authenticated,
            role: revoked.role,
            user: revoked,
            location: '/wk/home'),
        '/sales/account');
  });

  test('server grants survive persistence and empty sets deny role defaults',
      () {
    final original = user(['mobile-sales-orders']);
    final restored = AppUser.fromJson(original.toJson());
    expect(canAccessMobilePath(restored, '/sales/orders'), isTrue);
    expect(canAccessMobilePath(restored, '/sales/order/DH-001'), isTrue);
    expect(canAccessMobilePath(restored, '/sales/new-order/retailer'), isFalse);
    expect(canAccessMobilePath(user([]), '/sales/orders'), isFalse);
    expect(canAccessMobilePath(user([]), '/sales/account'), isTrue);
    expect(canAccessMobilePath(user([]), '/notifications'), isTrue);
    expect(canAccessMobilePath(user([]), '/sales/unknown'), isFalse);
    expect(canAccessMobilePath(null, '/sales/account'), isFalse);
  });

  test('create, scan, picking and operations use their independent grants', () {
    expect(
        screenPermissionFor('/retailer/order/new'), 'mobile-rt-order-create');
    expect(screenPermissionFor('/retailer/order/DH-001'), 'mobile-rt-orders');
    expect(screenPermissionFor('/retailer/receive/DH-001'), 'mobile-rt-scan');
    expect(
        screenPermissionFor('/wk/picking/PK-001/line/1'), 'mobile-wk-picking');
    expect(screenPermissionFor('/wk/picking'), 'mobile-wk-operations');
    expect(screenPermissionFor('/wk/operations'), 'mobile-wk-operations');
    expect(screenPermissionFor('/wk/documents/factoryReceipt'),
        'mobile-wk-operations');
    expect(screenPermissionFor('/wk/label/TEM-001'), 'mobile-wk-label');
    expect(screenPermissionFor('/sales/declarations'),
        'mobile-sales-declarations');
    expect(screenPermissionFor('/sales/declare'), 'mobile-sales-declare');
  });

  test('shared document details retain picking and shipped entry grants', () {
    expect(canAccessMobilePath(user(['mobile-wk-picking']), '/wk/document/id'),
        isTrue);
    expect(canAccessMobilePath(user(['mobile-wk-shipped']), '/wk/document/id'),
        isTrue);
    expect(canAccessMobilePath(user([]), '/wk/document/id'), isFalse);
  });

  test(
      'legacy stored sessions with no grants fail closed until profile refresh',
      () {
    final restored = AppUser.fromJson({'role': 'Sales'});
    expect(restored.permissions, isEmpty);
    expect(canAccessMobilePath(restored, '/sales/orders'), isFalse);
  });
}
