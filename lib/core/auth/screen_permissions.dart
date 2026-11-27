import 'session.dart';

/// Server screen keys for all registered mobile business paths, including details.
String? screenPermissionFor(String location) {
  final path = Uri.parse(location).path;
  if (path == '/notifications' || path.endsWith('/account')) return null;
  const paths = <String, String>{
    '/sales/home': 'mobile-sales-home',
    '/sales/orders': 'mobile-sales-orders',
    '/sales/order/': 'mobile-sales-orders',
    '/sales/new-order/': 'mobile-sales-order-create',
    '/sales/scan': 'mobile-sales-scan',
    '/sales/retailers': 'mobile-sales-retailers',
    '/sales/declare': 'mobile-sales-declare',
    '/sales/declarations': 'mobile-sales-declarations',
    '/sales/products': 'mobile-sales-products',
    '/sales/promotions': 'mobile-sales-promos',
    '/sales/debts': 'mobile-sales-debts',
    '/sales/kpi': 'mobile-sales-kpi',
    '/sales/sync': 'mobile-sales-sync',
    '/retailer/orders': 'mobile-rt-orders',
    '/retailer/order/new': 'mobile-rt-order-create',
    '/retailer/order/': 'mobile-rt-orders',
    '/retailer/scan': 'mobile-rt-scan',
    '/retailer/receive/': 'mobile-rt-scan',
    '/retailer/payments': 'mobile-rt-payments',
    '/retailer/loyalty': 'mobile-rt-loyalty',
    '/retailer/gifts': 'mobile-rt-gifts',
    '/retailer/complaints': 'mobile-rt-complaints',
    '/retailer/complaint-new': 'mobile-rt-complaints',
    '/wk/home': 'mobile-wk-picking',
    '/wk/order-picking': 'mobile-wk-picking',
    '/wk/picking/': 'mobile-wk-picking',
    '/wk/operations': 'mobile-wk-operations',
    '/wk/documents': 'mobile-wk-operations',
    '/wk/document/': 'mobile-wk-operations',
    '/wk/picking': 'mobile-wk-operations',
    '/wk/shipped': 'mobile-wk-shipped',
    '/wk/label-lookup': 'mobile-wk-label',
    '/wk/label/': 'mobile-wk-label',
  };
  for (final entry in paths.entries) {
    if (path == entry.key ||
        path.startsWith(
            entry.key.endsWith('/') ? entry.key : '${entry.key}/')) {
      return entry.value;
    }
  }
  return 'unmapped-mobile-screen';
}

bool canAccessMobilePath(AppUser? user, String path) {
  if (user == null) return false;
  // Shared details are reached from picking, operations and shipped history.
  // The server checks the actual document reason, status and warehouse scope.
  if (Uri.parse(path).path.startsWith('/wk/document/')) {
    return const [
      'mobile-wk-picking',
      'mobile-wk-operations',
      'mobile-wk-shipped',
    ].any(user.hasPermission);
  }
  final permission = screenPermissionFor(path);
  return permission == null || user.hasPermission(permission);
}

/// Entry points are a registry of screens, not a role-to-permission matrix.
const mobileDestinations = <String, String>{
  '/sales/home': 'Tổng quan bán hàng',
  '/sales/orders': 'Đơn bán hàng',
  '/sales/products': 'Sản phẩm',
  '/sales/retailers': 'Điểm bán',
  '/sales/declare': 'Khai báo điểm bán',
  '/sales/declarations': 'Danh sách khai báo',
  '/sales/promotions': 'Khuyến mãi',
  '/sales/debts': 'Công nợ bán hàng',
  '/sales/kpi': 'KPI bán hàng',
  '/sales/sync': 'Đồng bộ đơn hàng',
  '/sales/scan': 'Quét mã hàng',
  '/wk/home': 'Soạn hàng',
  '/wk/operations': 'Nhập · Xuất kho',
  '/wk/shipped': 'Lịch sử xuất hàng',
  '/wk/label-lookup': 'Tra cứu thùng hàng',
  '/retailer/orders': 'Đơn đặt hàng',
  '/retailer/order/new': 'Tạo đơn đặt hàng',
  '/retailer/scan': 'Quét nhận hàng',
  '/retailer/payments': 'Thanh toán',
  '/retailer/loyalty': 'Tích điểm',
  '/retailer/gifts': 'Đổi quà',
  '/retailer/complaints': 'Khiếu nại',
};

String firstGrantedMobilePath(AppUser user) => mobileDestinations.keys
    .firstWhere((path) => canAccessMobilePath(user, path),
        orElse: () => '/sales/account');
