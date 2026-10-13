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
    required String retailerCode,
    required List<CartLine> lines,
  }) async {
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
