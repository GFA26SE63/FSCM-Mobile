import 'dart:convert';

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
    final version = _requiredString(json, 'version');
    final generatedAt = asDate(json['generatedAt']);

    if (generatedAt == null) {
      throw const FormatException(
        'Snapshot thiếu generatedAt hợp lệ.',
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

      // Không tự suy diễn region/area/contact ngoài contract snapshot.
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

      if (previous == null ||
          asDate(row['effectiveFrom'])!
              .isAfter(asDate(previous['effectiveFrom'])!)) {
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
        // Các model compatibility hiện dùng int.
        // Giá chính xác vẫn được giữ trong raw/priceForProduct().
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

      final allProducts = productIds.isEmpty && categoryIds.isEmpty;

      final matchingSkus = publishedRows
          .where(
            (product) =>
                allProducts ||
                productIds.contains(asStr(product['id'])) ||
                categoryIds.contains(asStr(product['categoryId'])),
          )
          .map((product) => _requiredString(product, 'sku'))
          .toSet()
          .toList();

      final startsAt = asDate(row['startAt']);
      final endsAt = asDate(row['endAt']);

      if (startsAt == null || endsAt == null || endsAt.isBefore(startsAt)) {
        throw const FormatException(
          'Khuyến mãi có thời gian hiệu lực không hợp lệ.',
        );
      }

      final perSku = row['campaignMode'] == 'PerSku';
      final rules = <PromoRule>[];

      if (perSku) {
        for (final rule in _rows(row, 'productRules')) {
          final productId = _requiredString(rule, 'productId');
          final product = productsById[productId];

          if (product == null) continue;

          final sku = _requiredString(product, 'sku');

          if (!matchingSkus.contains(sku)) continue;

          rules.add(
            PromoRule(
              sku: sku,
              minQty: _number(rule, 'minimumQuantity').ceil(),
              pct: _number(rule, 'discountPercent').toDouble(),
            ),
          );
        }
      }

      promotions.add(
        Promotion(
          id: _requiredString(row, 'id'),
          name: _requiredString(row, 'name'),
          type: perSku ? 1 : 2,
          rules: rules,
          validFrom: startsAt,
          validTo: endsAt,
          active: true,
          usesExactTimes: true,
          retailerCodes: retailerIds.isEmpty
              ? null
              : retailerIds
                  .where(retailerCodesById.containsKey)
                  .map((id) => retailerCodesById[id]!)
                  .toList(),
          groupSkus: matchingSkus,
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
          available: _number(row, 'indicativeAvailableQuantity').floor(),
        ),
      );
    }

    return SyncSnapshot._(
      raw: _copyJson(json),
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

  List<MlorSummary> mlorSummariesForRetailer(String retailerId) {
    final categories = {
      for (final row in _rows(raw, 'categories'))
        asStr(row['id']): asStr(row['name']),
    };
    final products = {
      for (final row in _rows(raw, 'products'))
        asStr(row['id']): asStr(row['sku']),
    };
    final result = _rows(raw, 'mlors')
        .where((row) => asStr(row['retailerId']) == retailerId)
        .map((row) {
      final productId = asStr(row['productId']);
      final categoryId = asStr(row['categoryId']);
      return MlorSummary(
        source: productId.isNotEmpty
            ? 'SKU ${products[productId] ?? productId}'
            : 'Ngành hàng ${categories[categoryId] ?? categoryId}',
        minimumLifeRatio: _number(row, 'minimumLifeRatio').toDouble(),
        minimumLifeHours: row['minimumLifeHours'] is num
            ? (row['minimumLifeHours'] as num).toInt()
            : null,
        version: (row['version'] as num).toInt(),
      );
    }).toList()
      ..sort((a, b) => a.source.compareTo(b.source));

    final fallback = asMap(raw['defaultMlor']);
    if (fallback.isNotEmpty) {
      result.add(MlorSummary(
        source: 'Mặc định hệ thống',
        minimumLifeRatio: _number(fallback, 'minimumLifeRatio').toDouble(),
        version: (fallback['version'] as num).toInt(),
      ));
    }
    return List.unmodifiable(result);
  }

  Map<String, dynamic> toJson() => _copyJson(raw);

  static Map<String, dynamic> _copyJson(
    Map<String, dynamic> value,
  ) {
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  static bool _effectiveAt(
    Map<String, dynamic> row,
    DateTime at,
  ) {
    final start = asDate(row['effectiveFrom']);
    final rawEnd = row['effectiveTo'];
    final end = asDate(rawEnd);

    if (start == null || (rawEnd != null && end == null)) {
      throw const FormatException(
        'Bản giá có thời gian hiệu lực không hợp lệ.',
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

class MlorSummary {
  const MlorSummary({
    required this.source,
    required this.minimumLifeRatio,
    required this.version,
    this.minimumLifeHours,
  });

  final String source;
  final double minimumLifeRatio;
  final int? minimumLifeHours;
  final int version;
}
