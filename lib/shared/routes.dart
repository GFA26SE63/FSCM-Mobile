/// Route paths of the whole app. Lives in `shared` so feature screens can
/// navigate without importing `app/` (dependency direction: app -> features
/// -> shared). `app/router.dart` maps every constant below to a screen.
class AppRoutes {
  AppRoutes._();

  // ---------------------------------------------------------------- common
  static const String splash = '/splash';
  static const String login = '/login';
  static const String notifications = '/notifications';

  // ----------------------------------------------------------------- sales
  static const String salesHome = '/sales/home';
  static const String salesOrders = '/sales/orders';
  static const String salesScan = '/sales/scan';
  static const String salesSync = '/sales/sync';
  static const String salesAccount = '/sales/account';
  static const String salesRetailers = '/sales/retailers';
  static const String salesProducts = '/sales/products';
  static const String salesPromotions = '/sales/promotions';
  static const String salesDebts = '/sales/debts';
  static const String salesKpi = '/sales/kpi';
  static const String salesDeclare = '/sales/declare';
  static const String salesDeclarations = '/sales/declarations';
  static const String salesNewOrderPattern = '/sales/new-order/:retailerCode';
  static const String salesOrderDetailPattern = '/sales/order/:code';

  static String salesNewOrder(String retailerCode) =>
      '/sales/new-order/$retailerCode';
  static String salesOrderDetail(String code) =>
      '/sales/order/${Uri.encodeComponent(code)}';

  // ------------------------------------------------------- warehouse keeper
  static const String wkHome = '/wk/home';
  static const String wkPicking = '/wk/picking';
  static const String wkTransfers = '/wk/transfers';
  static const String wkAccount = '/wk/account';
  static const String wkScan = '/wk/scan';
  static const String wkShipped = '/wk/shipped';
  static const String wkLabelLookup = '/wk/label-lookup';
  static const String wkPickingDetailPattern = '/wk/picking/:code';
  static const String wkPickGatherPattern =
      '/wk/picking/:code/gather/:gatherId';
  static const String wkOrderIssuePattern =
      '/wk/picking/:code/order/:orderCode';
  static const String wkTransferDetailPattern = '/wk/transfer/:code';
  static const String wkLabelPattern = '/wk/label/:code';

  static String wkPickingDetail(String code) => '/wk/picking/$code';

  /// The scan screen of one gather (F44). Keyed by the gather, not by a
  /// position in a list: a sheet is regrouped by the server as it is picked,
  /// so an index would point at a different batch after a refresh.
  static String wkPickGather(String code, String gatherId) =>
      '/wk/picking/$code/gather/$gatherId';

  /// Readiness and issue of one order on a sheet (F93, F96).
  static String wkOrderIssue(String code, String orderCode) =>
      '/wk/picking/$code/order/$orderCode';
  static String wkTransferDetail(String code) => '/wk/transfer/$code';
  static String wkLabel(String code) => '/wk/label/$code';

  // --------------------------------------------------------------- retailer
  static const String rtOrders = '/retailer/orders';
  static const String rtScan = '/retailer/scan';
  static const String rtAccount = '/retailer/account';
  static const String rtPayments = '/retailer/payments';
  static const String rtLoyalty = '/retailer/loyalty';
  static const String rtGifts = '/retailer/gifts';
  static const String rtComplaints = '/retailer/complaints';
  static const String rtComplaintNew = '/retailer/complaint-new';
  static const String rtOrderDetailPattern = '/retailer/order/:code';
  static const String rtReceivePattern = '/retailer/receive/:code';

  static String rtOrderDetail(String code) => '/retailer/order/$code';
  static String rtReceive(String code) => '/retailer/receive/$code';

  /// `/retailer/complaint-new?order=DH-001021`
  static String rtComplaintFor(String orderCode) =>
      '$rtComplaintNew?order=$orderCode';
}
