import 'package:fscm_mobile/data/models/json_utils.dart';

/// Published SKU (SPEC section 4, Catalog). Prices are per carton (thùng).
class Product {
  const Product({
    this.id = '',
    required this.sku,
    required this.name,
    required this.pack,
    required this.category,
    required this.basePrice,
    this.shelfLifeDays = 30,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: asStr(j['id']),
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        pack: asStr(j['pack'] ?? j['unit']),
        category: asStr(j['category'] ?? j['categoryName']),
        basePrice: asInt(j['basePrice'] ?? j['price'] ?? j['currentUnitPrice']),
        shelfLifeDays: j['shelfLifeDays'] != null
            ? asInt(j['shelfLifeDays'], 30)
            : (asInt(j['shelfLifeHours'], 720) / 24).ceil(),
      );

  final String id;
  final String sku;
  final String name;
  final String pack;
  final String category;
  final int basePrice;
  final int shelfLifeDays;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sku': sku,
        'name': name,
        'pack': pack,
        'category': category,
        'basePrice': basePrice,
        'shelfLifeDays': shelfLifeDays,
      };
}

/// One row of LocalPrice: effective unit price of a SKU.
class PriceEntry {
  const PriceEntry({required this.sku, required this.price});

  factory PriceEntry.fromJson(Map<String, dynamic> j) =>
      PriceEntry(sku: asStr(j['sku']), price: asInt(j['price']));

  final String sku;
  final int price;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'sku': sku, 'price': price};
}

/// One row of LocalInventorySnapshot: available cartons per SKU.
class StockEntry {
  const StockEntry({required this.sku, required this.available});

  factory StockEntry.fromJson(Map<String, dynamic> j) =>
      StockEntry(sku: asStr(j['sku']), available: asInt(j['available']));

  final String sku;
  final int available;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'sku': sku, 'available': available};
}
