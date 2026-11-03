import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';

final productsApiProvider =
    Provider<ProductsApi>((ref) => ProductsApi(ref.watch(apiClientProvider)));

/// Catalog (`/products`) and authoritative indicative pricing.
class ProductsApi {
  ProductsApi(this._client);

  final ApiClient _client;

  Future<List<Product>> products({String? search}) async {
    final data = await _client.get(
      Endpoints.products,
      query: <String, dynamic>{'search': search, 'size': 200},
    );
    return unwrapItems(data).map(Product.fromJson).toList();
  }

  Future<List<Promotion>> promotions() async {
    final data = await _client.get(Endpoints.promotions);
    return unwrapItems(data).map(Promotion.fromJson).toList();
  }

  /// Authoritative online quote used by the order screen when connected.
  Future<PriceQuote> quote({
    required String retailerId,
    required List<CartLine> lines,
  }) async {
    final data = await _client.post(
      Endpoints.cartPricingQuote,
      body: <String, dynamic>{
        'retailerId': retailerId,
        'lines': lines
            .map((line) => <String, dynamic>{
                  'productId': line.productId,
                  'quantity': line.qty,
                })
            .toList(),
      },
    );
    final pricedLines = <QuoteLine>[];
    final promotionNames = <String, String>{};
    final promotionAmounts = <String, int>{};
    final promotionSkus = <String, List<String>>{};
    var total = 0;
    var discount = 0;
    for (final row in unwrapItems(data)) {
      final promotion = asMap(row['appliedPromotion']);
      final lineDiscount = asInt(row['discountAmount']);
      final quantity = asInt(row['quantity']);
      pricedLines.add(QuoteLine(
        sku: asStr(row['sku']),
        name: asStr(row['productName']),
        qty: quantity,
        unitPrice: asInt(row['unitPrice']),
        discount: lineDiscount,
        promoId: asStr(promotion['promotionId']),
        promoName: asStr(promotion['name']),
        pct: asDouble(row['discountPercent']),
      ));
      total += asInt(row['grossAmount']);
      discount += lineDiscount;
      if (promotion.isNotEmpty) {
        final id = asStr(promotion['promotionId']);
        promotionNames[id] = asStr(promotion['name']);
        promotionAmounts[id] = (promotionAmounts[id] ?? 0) + lineDiscount;
        promotionSkus.putIfAbsent(id, () => <String>[])
            .add('${asStr(row['sku'])} × $quantity');
      }
    }
    final applied = promotionAmounts.entries
        .map((entry) => AppliedPromo(
              id: entry.key,
              name: promotionNames[entry.key] ?? '',
              typeLabel: 'Khuyến mãi số lượng',
              detail: promotionSkus[entry.key]!.join(' + '),
              amount: entry.value,
            ))
        .toList();
    return PriceQuote(
      lines: pricedLines,
      applied: applied,
      total: total,
      discount: discount,
    );
  }
}
