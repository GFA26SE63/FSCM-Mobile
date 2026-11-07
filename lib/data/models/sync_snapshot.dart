import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/data/models/retailer.dart';

class SyncSnapshot {
  SyncSnapshot._({
    required this.raw,
    required this.version,
    required this.checksum,
    required this.generatedAt,
    required this.retailers,
    required this.products,
    required this.prices,
    required this.promotions,
    required this.stock,
    required this.stockDisclaimer,
    required this.priceDisclaimer,
  });

  final Map<String, dynamic> raw;

  final String version;
  final String checksum;
  final DateTime generatedAt;

  final List<Retailer> retailers;
  final List<Product> products;
  final List<PriceEntry> prices;
  final List<Promotion> promotions;
  final List<StockEntry> stock;

  final String stockDisclaimer;
  final String priceDisclaimer;

  // Compatibility với SyncService hiện tại.
  DateTime get serverTime => generatedAt;
  bool get fullReload => true;

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    final version = asStr(json['version']);
    final generatedAt = asDate(json['generatedAt']);

    if (version.isEmpty || generatedAt == null) {
      throw const FormatException(
        'Snapshot thiếu version hoặc generatedAt.',
      );
    }

    if (json['deltaMode'] != 'Full') {
      throw const FormatException(
        'Mobile hiện chỉ hỗ trợ Full snapshot.',
      );
    }

    final retailerRows = _rows(json, 'retailers');
    final categoryRows = _rows(json, 'categories');
    final productRows = _rows(json, 'products');
    final priceRows = _rows(json, 'prices');
    final promotionRows = _rows(json, 'promotions');
    final stockRows = _rows(json, 'indicativeStock');

    final categoriesById = {
      for (final row in categoryRows) _requiredString(row, 'id'): row,
    };

    final publishedRows =
        productRows.where((row) => row['status'] == 'Published').toList();

    final productsById = {
      for (final row in publishedRows) _requiredString(row, 'id'): row,
    };

    final retailers = retailerRows.map((row) {
      _requiredString(row, 'id');
      _requiredString(row, 'code');

      // Snapshot không có region/area/contact.
      // Không tự suy diễn các trường đó.
      return Retailer.fromJson(row);
    }).toList();

    final retailerCodesById = {
      for (final retailer in retailers) retailer.id: retailer.code,
    };

    final effectivePrices = <String, Map<String, dynamic>>{};

    for (final row in priceRows) {
      final productId = _requiredString(row, 'productId');

      if (!productsById.containsKey(productId)) continue;
      if (!asBool(row['isActive'])) continue;
      if (!_effectiveAt(row, generatedAt)) continue;

      _number(row, 'unitPrice');

      final previous = effectivePrices[productId];
      final startsAt = asDate(row['effectiveFrom'])!;

      if (previous == null ||
          startsAt.isAfter(asDate(previous['effectiveFrom'])!)) {
        effectivePrices[productId] = row;
      }
    }

    final products = publishedRows.map((row) {
      final id = _requiredString(row, 'id');
      final categoryId = _requiredString(row, 'categoryId');
      final category = categoriesById[categoryId];
      final price = effectivePrices[id];

      return Product(
        id: id,
        sku: _requiredString(row, 'sku'),
        name: _requiredString(row, 'name'),
        pack: asStr(row['unit']),
        category:
            category == null ? 'Chưa có tên danh mục' : asStr(category['name']),
        // Model giá cũ dùng int; chỉ phục vụ compatibility.
        // Giá gốc vẫn được giữ nguyên trong raw.
        basePrice: price == null ? 0 : _number(price, 'unitPrice').round(),
        shelfLifeDays: (_number(row, 'shelfLifeHours') / 24).ceil(),
      );
    }).toList();

    final prices = effectivePrices.entries.map((entry) {
      final product = productsById[entry.key]!;

      return PriceEntry(
        sku: _requiredString(product, 'sku'),
        price: _number(entry.value, 'unitPrice').round(),
      );
    }).toList();

    final promotions = <Promotion>[];

    for (final row in promotionRows) {
      if (row['type'] != 'Campaign') continue;
      if (!asBool(row['isActive'])) continue;

      final productIds = asStrList(row['productIds']).toSet();
      final categoryIds = asStrList(row['categoryIds']).toSet();
      final retailerIds = asStrList(row['retailerIds']);

      final matchingSkus = publishedRows
          .where(
            (product) =>
                productIds.contains(asStr(product['id'])) ||
                categoryIds.contains(asStr(product['categoryId'])),
          )
          .map((product) => _requiredString(product, 'sku'))
          .toSet()
          .toList();

      final startsAt = asDate(row['startAt']);
      final endsAt = asDate(row['endAt']);

      if (startsAt == null || endsAt == null) {
        throw const FormatException(
          'Khuyến mãi thiếu thời gian hiệu lực.',
        );
      }

      promotions.add(
        Promotion(
          id: _requiredString(row, 'id'),
          name: _requiredString(row, 'name'),
          // Campaign dùng tổng lượng các SKU phù hợp.
          type: 2,
          validFrom: startsAt,
          validTo: endsAt,
          active: true,
          retailerCodes: retailerIds.isEmpty
              ? null
              : retailerIds
                  .where(retailerCodesById.containsKey)
                  .map((id) => retailerCodesById[id]!)
                  .toList(),
          groupSkus: matchingSkus,
          // Số lượng đặt hiện tại là thùng nguyên.
          groupMinQty: _number(row, 'minimumQuantity').ceil(),
          groupPct: _number(row, 'discountPercent').toDouble(),
        ),
      );
    }

    final stock = <StockEntry>[];

    for (final row in stockRows) {
      final productId = _requiredString(row, 'productId');
      final product = productsById[productId];

      if (product == null) continue;

      stock.add(
        StockEntry(
          sku: _requiredString(product, 'sku'),
          available: _number(
            row,
            'indicativeAvailableQuantity',
          ).floor(),
        ),
      );
    }

    return SyncSnapshot._(
      raw: Map<String, dynamic>.from(json),
      version: version,
      checksum: asStr(json['checksum']),
      generatedAt: generatedAt,
      retailers: retailers,
      products: products,
      prices: prices,
      promotions: promotions,
      stock: stock,
      stockDisclaimer: asStr(json['stockDisclaimer']),
      priceDisclaimer: asStr(json['priceDisclaimer']),
    );
  }

  Map<String, dynamic>? promotionRecord(String id) {
    for (final row in _rows(raw, 'promotions')) {
      if (row['id'] == id) return row;
    }

    return null;
  }

  String promotionCode(String id) {
    final row = promotionRecord(id);
    return row == null ? id : asStr(row['code'], id);
  }

  // Giá chính xác từ snapshot, không lấy giá int compatibility.
  num? priceForProduct(String productId, DateTime at) {
    Map<String, dynamic>? selected;

    for (final row in _rows(raw, 'prices')) {
      if (row['productId'] != productId) continue;
      if (!asBool(row['isActive'])) continue;
      if (!_effectiveAt(row, at)) continue;

      if (selected == null ||
          asDate(row['effectiveFrom'])!
              .isAfter(asDate(selected['effectiveFrom'])!)) {
        selected = row;
      }
    }

    return selected == null ? null : _number(selected, 'unitPrice');
  }

  num? stockForProduct(String productId) {
    for (final row in _rows(raw, 'indicativeStock')) {
      if (row['productId'] == productId) {
        return _number(row, 'indicativeAvailableQuantity');
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);

  static bool _effectiveAt(
    Map<String, dynamic> row,
    DateTime at,
  ) {
    final start = asDate(row['effectiveFrom']);
    final end = asDate(row['effectiveTo']);

    if (start == null) {
      throw const FormatException(
        'Bản giá thiếu effectiveFrom.',
      );
    }

    return !at.isBefore(start) && (end == null || at.isBefore(end));
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is! List || value.any((item) => item is! Map)) {
      throw FormatException('Snapshot có $key không hợp lệ.');
    }

    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static String _requiredString(
    Map<String, dynamic> row,
    String key,
  ) {
    final value = row[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Snapshot thiếu $key.');
    }

    return value;
  }

  static num _number(
    Map<String, dynamic> row,
    String key,
  ) {
    final value = row[key];

    if (value is! num || !value.isFinite) {
      throw FormatException('Snapshot có $key không hợp lệ.');
    }

    return value;
  }
}
