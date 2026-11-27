import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/features/warehouse/documents/warehouse_documents_screen.dart';

void main() {
  // Source transfer issue: operated by WH-A, destined to WH-B.
  final issue = {'warehouseId': 'A', 'destinationWarehouseId': 'B'};
  final receipt = {'warehouseId': 'B', 'destinationWarehouseId': 'B'};

  test('destination keeper does not own the source issue (no history/progress)',
      () {
    expect(ownsDocument(['B'], issue), isFalse);
  });
  test('destination keeper owns the child receipt', () {
    expect(ownsDocument(['B'], receipt), isTrue);
  });
  test('unauthorized keeper owns neither', () {
    expect(ownsDocument(['C'], issue), isFalse);
    expect(ownsDocument(['C'], receipt), isFalse);
    expect(ownsDocument(null, receipt), isFalse);
  });

  test('destination warehouse outside the scope shows its directory name', () {
    const keeper = AppUser(
        id: 'k',
        fullName: 'Thủ kho',
        phone: '',
        role: UserRole.warehouseKeeper,
        warehouseIds: [
          'A'
        ],
        warehouseLabels: [
          ScopeLabel(id: 'A', code: 'BC', name: 'Kho Bến Cát')
        ]);
    const names = {'A': 'Kho A (danh mục)', 'B': 'Kho Thủ Đức'};
    expect(warehouseLabel(keeper, names, 'A'), 'Kho Bến Cát');
    expect(warehouseLabel(keeper, names, 'B'), 'Kho Thủ Đức');
    expect(warehouseLabel(keeper, null, 'B'), 'B');
    expect(warehouseLabel(keeper, const {}, 'B'), 'B');
  });
}
