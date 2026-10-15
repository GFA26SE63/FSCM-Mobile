/// Business ID rules decided 06/10/2026 (SPEC section 3).
///
/// Mirrors `FSCM.SharedKernel.Ids.IdFormat` on the backend so the mobile app
/// can validate scanned / typed codes and build offline codes locally.
/// Pure Dart: no Flutter imports (unit-tested in test/id_format_test.dart).
library;

/// Document prefixes `{PN|PH|DC|KN|KMB}-{yyMMdd}-{nn}`.
enum DocPrefix {
  /// Phiếu nhập kho (goods receipt).
  pn('PN'),

  /// Phiếu hủy (disposal).
  ph('PH'),

  /// Điều chuyển / luân chuyển (transfer).
  dc('DC'),

  /// Khiếu nại (complaint).
  kn('KN'),

  /// Khuyến mãi theo HSD (batch discount).
  kmb('KMB');

  const DocPrefix(this.code);
  final String code;
}

class IdFormat {
  IdFormat._();

  static String _pad(int value, int width) {
    if (value < 0) throw ArgumentError.value(value, 'value', 'must be >= 0');
    final s = value.toString();
    if (s.length > width) {
      throw ArgumentError.value(value, 'value', 'exceeds $width digits');
    }
    return s.padLeft(width, '0');
  }

  static String _ddMMyyyy(DateTime d) =>
      '${_pad(d.day, 2)}${_pad(d.month, 2)}${_pad(d.year, 4)}';

  static String _yyMMdd(DateTime d) =>
      '${_pad(d.year % 100, 2)}${_pad(d.month, 2)}${_pad(d.day, 2)}';

  // ---------------------------------------------------------------- builders

  /// Retailer: 8 digits (`10004288`), synced with the SAP customer code.
  static String retailer(int number) => _pad(number, 8);

  /// Retailer registration request `KB-0000`.
  static String registration(int seq) => 'KB-${_pad(seq, 4)}';

  /// Sales group `{area}-{letter}`, e.g. `Q12-A`.
  static String salesGroup(String areaCode, String letter) =>
      '${areaCode.toUpperCase()}-${letter.toUpperCase()}';

  /// Category `CAT-00`.
  static String category(int seq) => 'CAT-${_pad(seq, 2)}';

  /// SKU `SKU000`.
  static String sku(int seq) => 'SKU${_pad(seq, 3)}';

  /// Warehouse `WH-XX` (2+ letters, e.g. `WH-TA`, `WH-TCH`).
  static String warehouse(String abbreviation) =>
      'WH-${abbreviation.toUpperCase()}';

  /// Batch `{WH}-{SKU}-{ddMMyyyy expiry}`, e.g. `WH-GV-SKU002-12102026`.
  static String batch(String warehouseCode, String skuCode, DateTime expiry) =>
      '$warehouseCode-$skuCode-${_ddMMyyyy(expiry)}';

  /// Label `TEM-000000`.
  static String label(int seq) => 'TEM-${_pad(seq, 6)}';

  /// Order `DH-000000`.
  static String order(int seq) => 'DH-${_pad(seq, 6)}';

  /// Offline order `OFF-{device}-{0000}`; always paired with a UUID
  /// `clientRequestId` used as idempotency key by `POST /orders/sync`.
  static String offlineOrder(String deviceCode, int seq) =>
      'OFF-${deviceCode.toUpperCase()}-${_pad(seq, 4)}';

  /// Picking list `{order}{A/B/C}` - one per warehouse, e.g. `DH-001024B`.
  static String pickingList(String orderCode, int warehouseIndex) {
    if (warehouseIndex < 0 || warehouseIndex > 25) {
      throw ArgumentError.value(warehouseIndex, 'warehouseIndex', '0..25');
    }
    return '$orderCode${String.fromCharCode(65 + warehouseIndex)}';
  }

  /// Documents `{PN|PH|DC|KN|KMB}-{yyMMdd}-{nn}`, e.g. `DC-260927-01`.
  static String document(DocPrefix prefix, DateTime date, int seq) =>
      '${prefix.code}-${_yyMMdd(date)}-${_pad(seq, 2)}';

  /// Promotion `KM-000`.
  static String promotion(int seq) => 'KM-${_pad(seq, 3)}';

  /// Loyalty program `LP-000`.
  static String loyaltyProgram(int seq) => 'LP-${_pad(seq, 3)}';

  /// Gift `QUA-000`.
  static String gift(int seq) => 'QUA-${_pad(seq, 3)}';

  /// Gift request `DQ-yyMMdd-nn`.
  static String giftRequest(DateTime date, int seq) =>
      'DQ-${_yyMMdd(date)}-${_pad(seq, 2)}';

  /// Driver `NG-000`.
  static String driver(int seq) => 'NG-${_pad(seq, 3)}';

  // ------------------------------------------------------------- validators

  static final RegExp retailerPattern = RegExp(r'^\d{8}$');
  static final RegExp registrationPattern = RegExp(r'^KB-\d{4}$');
  static final RegExp salesGroupPattern = RegExp(r'^[A-Z0-9]+-[A-Z]$');
  static final RegExp categoryPattern = RegExp(r'^CAT-\d{2}$');
  static final RegExp skuPattern = RegExp(r'^SKU\d{3}$');
  static final RegExp warehousePattern = RegExp(r'^WH-[A-Z]{2,4}$');
  static final RegExp batchPattern =
      RegExp(r'^(WH-[A-Z]{2,4})-(SKU\d{3})-(\d{2})(\d{2})(\d{4})$');
  static final RegExp labelPattern = RegExp(r'^TEM-\d{6}$');
  static final RegExp orderPattern = RegExp(r'^DH-\d{6}$');
  static final RegExp offlineOrderPattern =
      RegExp(r'^OFF-[A-Z0-9]{2,8}-\d{4}$');
  static final RegExp pickingListPattern = RegExp(r'^DH-\d{6}[A-Z]$');
  static final RegExp documentPattern =
      RegExp(r'^(PN|PH|DC|KN|KMB)-\d{6}-\d{2}$');
  static final RegExp promotionPattern = RegExp(r'^KM-\d{3}$');
  static final RegExp loyaltyProgramPattern = RegExp(r'^LP-\d{3}$');
  static final RegExp giftPattern = RegExp(r'^QUA-\d{3}$');
  static final RegExp giftRequestPattern = RegExp(r'^DQ-\d{6}-\d{2}$');
  static final RegExp driverPattern = RegExp(r'^NG-\d{3}$');

  static bool isRetailer(String v) => retailerPattern.hasMatch(v);
  static bool isRegistration(String v) => registrationPattern.hasMatch(v);
  static bool isSku(String v) => skuPattern.hasMatch(v);
  static bool isWarehouse(String v) => warehousePattern.hasMatch(v);
  static bool isBatch(String v) => batchPattern.hasMatch(v);
  static bool isLabel(String v) => labelPattern.hasMatch(v);
  static bool isOrder(String v) => orderPattern.hasMatch(v);
  static bool isOfflineOrder(String v) => offlineOrderPattern.hasMatch(v);
  static bool isPickingList(String v) => pickingListPattern.hasMatch(v);
  static bool isDocument(String v) => documentPattern.hasMatch(v);
  static bool isGiftRequest(String v) => giftRequestPattern.hasMatch(v);

  /// Expiry date encoded in a batch code, or null when not a batch code.
  static DateTime? batchExpiry(String batchCode) {
    final m = batchPattern.firstMatch(batchCode);
    if (m == null) return null;
    final day = int.parse(m.group(3)!);
    final month = int.parse(m.group(4)!);
    final year = int.parse(m.group(5)!);
    final d = DateTime(year, month, day);
    if (d.day != day || d.month != month) return null;
    return d;
  }

  /// Order code a picking list belongs to (`DH-001024B` -> `DH-001024`).
  static String? orderOfPickingList(String pickingListCode) {
    if (!isPickingList(pickingListCode)) return null;
    return pickingListCode.substring(0, pickingListCode.length - 1);
  }

  /// Sequence number of an offline code (`OFF-M3F7-0012` -> 12).
  static int? offlineSeq(String offlineCode) {
    if (!isOfflineOrder(offlineCode)) return null;
    return int.parse(offlineCode.substring(offlineCode.lastIndexOf('-') + 1));
  }

  /// Classifies a raw QR payload (labels carry only their code).
  static ScannedCodeKind classify(String raw) {
    final v = raw.trim().toUpperCase();
    if (isLabel(v)) return ScannedCodeKind.label;
    if (isRetailer(v)) return ScannedCodeKind.retailer;
    if (isOrder(v)) return ScannedCodeKind.order;
    if (isPickingList(v)) return ScannedCodeKind.pickingList;
    if (isBatch(v)) return ScannedCodeKind.batch;
    if (isDocument(v)) return ScannedCodeKind.document;
    return ScannedCodeKind.unknown;
  }
}

enum ScannedCodeKind {
  label,
  retailer,
  order,
  pickingList,
  batch,
  document,
  unknown
}
