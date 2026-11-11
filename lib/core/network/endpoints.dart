/// REST endpoints used by the mobile app (SPEC section 8, prefix `/api/v1`
/// is part of `Env.apiBaseUrl`). Paging: `?page=&size=&search=`.
class Endpoints {
  Endpoints._();

  // ---------------------------------------------------------------- auth
  // Local credentials remain available; Google exchanges a verified ID token
  // for the same internal FSCM session contract.
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authOtpRequest = '/auth/otp/request';
  static const String authOtpVerify = '/auth/otp/verify';
  static const String authSetPassword = '/auth/password';
  static const String authLogout = '/auth/logout';
  static const String authGoogleExchange = '/auth/google/exchange';

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
  static String retailerOrderEligibility(String retailerId) =>
      '/retailers/$retailerId/order-eligibility';
  static String retailerMlor(String code) => '/retailers/$code/mlor';
  static String salesGroup(String id) => '/sales-groups/$id';

  /// Retailer declaration (Sales): `POST /retailers` creates, `PUT
  /// /retailers/{id}/declaration` updates a Draft/Rejected one, `POST
  /// /retailers/{id}/submit-review` sends it to Admin / Operator.
  static String retailerDeclaration(String id) => '/retailers/$id/declaration';
  static String retailerSubmitReview(String id) =>
      '/retailers/$id/submit-review';

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
  static String order(String id) => '/orders/$id';
  static String orderByCode(String code) => '/orders/by-code/$code';
  static String orderCancel(String code) => '/orders/$code/cancel';
  static String orderConfirmReceipt(String code) =>
      '/orders/$code/confirm-receipt';
  static const String ordersSync = '/orders/sync';
  static String quotesForOrder(String orderId) => '/quotes/orders/$orderId';
  static String quoteAccept(String quoteId) => '/quotes/$quoteId/accept';
  static String quoteReject(String quoteId) => '/quotes/$quoteId/reject';
  static const String pickingLists = '/picking-lists';
  static String pickingList(String code) => '/picking-lists/$code';
  static String pickingListScan(String code) => '/picking-lists/$code/scans';
  static String pickingListComplete(String code) =>
      '/picking-lists/$code/complete';
  static String shipmentDeliveryView(String orderId) =>
      '/shipments/orders/$orderId/delivery-view';
  static String shipmentReceipt(String shipmentId) =>
      '/shipments/$shipmentId/receipt';
  static const String complaints = '/complaints';

  // ------------------------------------------------------------- pricing
  static const String promotions = '/promotions';
  static const String pricingQuote = '/pricing/snapshot';
  static const String cartPricingQuote = '/pricing/cart-snapshot';

  // ------------------------------------------------------------- finance
  static const String receivables = '/receivables';
  static const String retailerReceivables = '/retailer/receivables';
  static const String retailerDebtPayOsCheckouts =
      '/retailer/receivables/payos-checkouts';
  static String retailerDebtPayOsCheckout(String checkoutId) =>
      '/retailer/receivables/payos-checkouts/$checkoutId';
  static String paymentForOrder(String orderId) => '/payments/orders/$orderId';
  static String payOsCheckout(String orderId) =>
      '/payments/orders/$orderId/payos-checkout';
  static String receivableCollect(String orderId) =>
      '/receivables/orders/$orderId/collect';

  // ------------------------------------------------------------- loyalty
  static const String loyaltyPrograms = '/loyalty/programs';
  static const String loyaltyCardMe = '/loyalty/cards/me';
  static const String loyaltyRewards = '/loyalty/rewards';
  static const String loyaltyRedemptions = '/loyalty/redemptions';

  // --------------------------------------------------------- performance
  static const String kpiSales = '/kpi/sales';
  static const String rankingsSales = '/rankings/sales';
  static const String rankingsProducts = '/rankings/products';

  // ------------------------------------------------------- notifications
  static const String notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  static const String graphql = '/graphql';

  // ---------------------------------------------------------- mobile sync
  /// `GET /sync/snapshot?since=` - retailers in area, products, prices,
  /// promotions, available stock summary.
  static const String syncSnapshot = '/mobile/snapshot';
}
