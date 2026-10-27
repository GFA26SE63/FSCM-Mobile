/// REST endpoints used by the mobile app (SPEC section 8, prefix `/api/v1`
/// is part of `Env.apiBaseUrl`). Paging: `?page=&size=&search=`.
class Endpoints {
  Endpoints._();

  // ---------------------------------------------------------------- auth
  // Mobile auth facade in front of Microsoft Entra External ID (phone OTP +
  // password). Not listed in SPEC section 8 yet - agree with backend team.
  static const String authLogin = '/auth/login';
  static const String authOtpRequest = '/auth/otp/request';
  static const String authOtpVerify = '/auth/otp/verify';
  static const String authSetPassword = '/auth/password';
  static const String authLogout = '/auth/logout';

  // ------------------------------------------------------------ identity
  static const String me = '/me';
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
  static String label(String code) => '/qr-labels/$code';
  static const String transfers = '/transfers';
  static String transfer(String code) => '/transfers/$code';
  static String transferReceive(String code) => '/transfers/$code/receive';

  // ------------------------------------------------------------ ordering
  static const String orders = '/orders';
  static String order(String code) => '/orders/$code';
  static String orderCancel(String code) => '/orders/$code/cancel';
  static String orderConfirmReceipt(String code) =>
      '/orders/$code/confirm-receipt';
  static String allocationRunOrderResult(String orderId) =>
      '/allocation-runs/orders/$orderId/result';
  static const String ordersSync = '/orders/sync';
  static const String complaints = '/complaints';

  // ------------------------------------------------------- run picking (F43)
  // One sheet per warehouse per allocation run, not one per order: a sheet
  // gathers by SKU/batch and then splits each gather back to the order lines
  // the run allocated it to.
  static const String pickingLists = '/picking-lists';
  static String pickingList(String code) => '/picking-lists/$code';

  /// F44. Needs an `Idempotency-Key` header; a repeat of the same key returns
  /// the sheet unchanged rather than picking the cartons twice.
  static String pickingListScans(String code) => '/picking-lists/$code/scans';

  /// Closes this warehouse's portion, or records an exception on it. The server
  /// refuses while any approved gather or split is still short.
  static String pickingListComplete(String code) =>
      '/picking-lists/$code/complete';

  // ------------------------------------------------- shipments (F93, F96)
  static const String shipments = '/shipments';
  static String shipment(String id) => '/shipments/$id';

  /// F93. Whether the whole order may leave, and which part is holding it.
  static String orderShipmentReadiness(String orderId) =>
      '/shipments/orders/$orderId/readiness';

  /// F96. Confirms this warehouse's part physically left. OnHand and Reserved
  /// fall together here and nowhere else; calling twice does not deduct twice.
  static String shipmentIssue(String id) => '/shipments/$id/issue';

  // ------------------------------------------------------------- pricing
  static const String promotions = '/promotions';
  static const String pricingQuote = '/pricing/quote';

  // ------------------------------------------------------------- finance
  static const String receivables = '/receivables';
  static String receivableCollect(String orderCode) =>
      '/receivables/$orderCode/collect';

  // ------------------------------------------------------------- loyalty
  static const String loyaltyPrograms = '/loyalty/programs';
  static const String loyaltyCardMe = '/loyalty/cards/me';
  static const String loyaltyRewards = '/loyalty/rewards';
  static const String loyaltyRedemptions = '/loyalty/redemptions';
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
