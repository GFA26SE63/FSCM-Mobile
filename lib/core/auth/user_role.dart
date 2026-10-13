/// Roles from SPEC section 2. Only [sales], [warehouseKeeper] and
/// [retailer] have a shell in the mobile app; the others use the Portal.
enum UserRole {
  sales('Sales', 'Sales Representative'),
  warehouseKeeper('WarehouseKeeper', 'Warehouse Keeper'),
  retailer('Retailer', 'Điểm bán'),
  admin('Admin', 'Admin'),
  operator('Operator', 'Operator'),
  salesManager('SalesManager', 'Sales Manager');

  const UserRole(this.code, this.label);

  /// Value used by the API (`role` claim / `GET /me`).
  final String code;

  /// Display label.
  final String label;

  bool get hasMobileShell =>
      this == UserRole.sales ||
      this == UserRole.warehouseKeeper ||
      this == UserRole.retailer;

  static UserRole fromCode(String? code) {
    final normalized = (code ?? '').replaceAll(' ', '').toLowerCase();
    for (final r in UserRole.values) {
      if (r.code.toLowerCase() == normalized) return r;
    }
    if (normalized == 'wk' || normalized == 'warehouse') {
      return UserRole.warehouseKeeper;
    }
    return UserRole.operator;
  }
}
