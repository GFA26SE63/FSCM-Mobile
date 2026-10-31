/// Roles from SPEC section 2 and SPRINT_1_FRONTEND_MOBILE_API_GUIDE.md §3.3.
/// Only [sales], [warehouseKeeper] and [retailer] have a shell in the mobile
/// app; [admin], [operator], and [salesManager] use the Portal.
enum UserRole {
  sales('Sales', 'Sales Representative'),
  warehouseKeeper('WarehouseKeeper', 'Warehouse Keeper'),
  retailer('Retailer', 'Điểm bán'),
  admin('Admin', 'Admin'),
  operator('Operator', 'Operator'),
  salesManager('SalesManager', 'Sales Manager'),
  unsupported('Unsupported', 'Vai trò chưa được hỗ trợ');

  const UserRole(this.code, this.label);

  /// Value used by the API (`role` claim / `GET /auth/me`).
  final String code;

  /// Display label.
  final String label;

  bool get hasMobileShell =>
      this == UserRole.sales ||
      this == UserRole.warehouseKeeper ||
      this == UserRole.retailer;

  bool get isSales => this == UserRole.sales;
  bool get isWarehouseKeeper => this == UserRole.warehouseKeeper;
  bool get isRetailer => this == UserRole.retailer;
  bool get isPortalOnly => !hasMobileShell;

  static UserRole fromCode(String? code) {
    final normalized = (code ?? '').replaceAll(' ', '').toLowerCase();
    for (final r in UserRole.values) {
      if (r.code.toLowerCase() == normalized) return r;
    }
    if (normalized == 'wk' || normalized == 'warehouse') {
      return UserRole.warehouseKeeper;
    }
    return UserRole.unsupported;
  }
}
