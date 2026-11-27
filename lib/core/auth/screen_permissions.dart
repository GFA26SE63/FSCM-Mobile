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
    // Refunds are read from the receivable views of the payments screen.
    '/retailer/refunds': 'mobile-rt-payments',
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
    return user.permissions == null ||
        const [
          'mobile-wk-picking',
          'mobile-wk-operations',
          'mobile-wk-shipped',
        ].any(user.permissions!.contains);
  }
  final permission = screenPermissionFor(path);
  return permission == null ||
      user.permissions == null ||
      user.permissions!.contains(permission);
}
