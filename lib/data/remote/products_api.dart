import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/data/remote/backend_catalog.dart';
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

/// Catalog (`/products`), pricing (`/promotions`, `POST /pricing/quote`).
class ProductsApi {
  ProductsApi(this._client, {bool useMock = Env.useMock}) : _useMock = useMock;

  final ApiClient _client;
  final bool _useMock;

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
    required String retailerCode,
    required List<CartLine> lines,
  }) async {
    if (!_useMock) {
      final retailerId = await resolveCatalogId(
          _client, Endpoints.retailers, 'code', retailerCode);
      final quoted = <QuoteLine>[];
      final applied = <AppliedPromo>[];
      for (final line in lines) {
        final id = await resolveCatalogId(
            _client, Endpoints.products, 'sku', line.sku);
        final data = asMap(await _client.get('/pricing/snapshot', query: {
          'productId': id,
          'retailerId': retailerId,
          'quantity': line.qty
        }));
        final promo = asMap(data['appliedPromotion']);
        quoted.add(QuoteLine(
            sku: asStr(data['sku']),
            name: asStr(data['productName']),
            qty: line.qty,
            unitPrice: asInt(data['unitPrice']),
            discount: asInt(data['discountAmount']),
            promoId: asStr(promo['promotionId']),
            promoName: asStr(promo['name']),
            pct: asDouble(data['discountPercent'])));
        if (promo.isNotEmpty) {
          applied.add(AppliedPromo(
              id: asStr(promo['promotionId']),
              name: asStr(promo['name']),
              typeLabel: 'Khuyến mãi',
              detail: line.sku,
              amount: asInt(data['discountAmount'])));
        }
      }
      return PriceQuote(
          lines: quoted,
          applied: applied,
          total: quoted.fold<int>(0, (sum, line) => sum + line.base),
          discount: quoted.fold<int>(0, (sum, line) => sum + line.discount));
    }
    final data = await _client.post(
      Endpoints.pricingQuote,
      body: <String, dynamic>{
        'retailerCode': retailerCode,
        'lines': lines.map((l) => l.toJson()).toList(),
      },
    );
    return PriceQuote.fromJson(asMap(data));
  }
}
