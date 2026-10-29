/// REST endpoints used by the mobile app (SPEC section 8, prefix `/api/v1`
/// is part of `Env.apiBaseUrl`). Paging: `?page=&size=&search=`.
class Endpoints {
  Endpoints._();

  // ---------------------------------------------------------------- auth
  // Auth endpoints per SPRINT_1_FRONTEND_MOBILE_API_GUIDE.md (§3.2, §5.1).
  static const String authLogin = '/auth/login';
  static const String authEntraExchange = '/auth/entra/exchange';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authMe = '/auth/me';
  static const String authActivate = '/auth/activate';
  static const String authPasswordResetRequest = '/auth/password-reset/request';
  static const String authPasswordResetConfirm = '/auth/password-reset/confirm';
  static const String authOtpRequest = '/auth/otp/request';
  static const String authOtpVerify = '/auth/otp/verify';
  static const String authSetPassword = '/auth/password';

  // ------------------------------------------------------------ identity
  static const String me = '/auth/me';
  static const String devices = '/devices';

  // ------------------------------------------------------------- catalog
  static const String categories = '/categories';
  static const String products = '/products';

  // ------------------------------------------------------------ partners
  static const String areas = '/areas';
  static const String salesGroups = '/sales-groups';
  static const String retailers = '/retailers';
  static String retailer(String code) => '/retailers/$code';
  static String retailerMlor(String code) => '/retailers/$code/mlor';
  static const String retailerRegistrations = '/retailer-registrations';
  static String retailerRegistration(String code) =>
      '/retailer-registrations/$code';

  // ----------------------------------------------------------- logistics
  static const String transitQuote = '/transit/quote';
  static const String vehicles = '/vehicles';
  static const String drivers = '/drivers';

  // ----------------------------------------------------------- inventory
  static const String warehouses = '/warehouses';
  static const String batches = '/batches';
  static String label(String code) => '/labels/$code';
  static const String transfers = '/transfers';
  static String transfer(String code) => '/transfers/$code';
  static String transferReceive(String code) => '/transfers/$code/receive';

  // ------------------------------------------------------------ ordering
  static const String orders = '/orders';
  static String order(String code) => '/orders/$code';
  static String orderCancel(String code) => '/orders/$code/cancel';
  static String orderConfirmReceipt(String code) =>
      '/orders/$code/confirm-receipt';
  static const String ordersSync = '/orders/sync';
  static const String pickingLists = '/picking-lists';
  static String pickingList(String code) => '/picking-lists/$code';
  static String pickingListScan(String code) => '/picking-lists/$code/scan';
  static String pickingListShip(String code) => '/picking-lists/$code/ship';
  static const String complaints = '/complaints';

  // ------------------------------------------------------------- pricing
  static const String promotions = '/promotions';
  static const String pricingQuote = '/pricing/quote';

  // ------------------------------------------------------------- finance
  static const String receivables = '/receivables';
  static String receivableCollect(String orderCode) =>
      '/receivables/$orderCode/collect';

  // ------------------------------------------------------------- loyalty
  static const String loyaltyPrograms = '/loyalty/programs';
  static String loyaltyRetailer(String code) => '/loyalty/retailers/$code';
  static const String gifts = '/gifts';
  static const String giftRedemptions = '/gift-redemptions';

  // --------------------------------------------------------- performance
  static const String kpiSales = '/kpi/sales';
  static const String rankingsSales = '/rankings/sales';
  static const String rankingsProducts = '/rankings/products';

  // ------------------------------------------------------- notifications
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';

  // ---------------------------------------------------------- mobile sync
  /// `GET /sync/snapshot?since=` - retailers in area, products, prices,
  /// promotions, available stock summary.
  static const String syncSnapshot = '/sync/snapshot';
}
