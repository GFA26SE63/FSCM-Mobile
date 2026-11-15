import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';

final productsApiProvider =
    Provider<ProductsApi>((ref) => ProductsApi(ref.watch(apiClientProvider)));

/// Catalog (`/products`) and authoritative indicative pricing.
class ProductsApi {
  ProductsApi(this._client);

  final ApiClient _client;

  Future<List<Product>> products({String? search}) async {
    final result = <Product>[];
    var page = 1;

    while (true) {
      final response = asMap(
        await _client.get(
          Endpoints.products,
          query: {
            'search': search,
            'status': 'Published',
            'page': page,
            'pageSize': 100,
          },
        ),
      );

      final items = unwrapItems(response);

      result.addAll(items.map(Product.fromJson));

      if (items.isEmpty || page >= asInt(response['totalPages'], 1)) {
        break;
      }

      page++;
    }

    return result;
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
    if (lines.isEmpty || lines.length > 100) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Giỏ hàng cần có từ 1 đến 100 dòng sản phẩm.',
      );
    }

    final expected = <String, int>{};

    for (final line in lines) {
      if (line.productId.isEmpty || line.qty <= 0) {
        throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Sản phẩm thiếu ID hoặc có số lượng không hợp lệ.',
        );
      }

      expected.update(
        line.productId,
        (quantity) => quantity + line.qty,
        ifAbsent: () => line.qty,
      );
    }

    final data = await _client.post(
      Endpoints.cartPricingQuote,
      body: <String, dynamic>{
        'retailerId': retailerId,
        'lines': expected.entries
            .map(
              (entry) => {
                'productId': entry.key,
                'quantity': entry.value,
              },
            )
            .toList(),
      },
    );

    ApiException invalidResponse() => const ApiException(
          kind: ApiErrorKind.server,
          message:
              'Phản hồi tính giá của máy chủ không đầy đủ hoặc không hợp lệ.',
        );

    num readNumber(Map<String, dynamic> row, String key) {
      final value = row[key];

      if (value is! num || !value.isFinite || value < 0) {
        throw invalidResponse();
      }

      return value;
    }

    final rows = unwrapItems(data);
    if (rows.length != expected.length) {
      throw invalidResponse();
    }

    final seen = <String>{};
    final pricedLines = <QuoteLine>[];
    final names = <String, String>{};
    final amounts = <String, int>{};
    final details = <String, List<String>>{};

    var total = 0;
    var discount = 0;

    for (final row in rows) {
      final productId = asStr(row['productId']);
      final quantity = readNumber(row, 'quantity');

      if (!expected.containsKey(productId) ||
          !seen.add(productId) ||
          quantity != expected[productId]) {
        throw invalidResponse();
      }

      final promotion = asMap(row['appliedPromotion']);
      final unitPrice = readNumber(row, 'unitPrice');
      final gross = readNumber(row, 'grossAmount').round();
      final lineDiscount = readNumber(row, 'discountAmount').round();
      final percent = readNumber(row, 'discountPercent').toDouble();
      final sku = asStr(row['sku']);

      if (sku.isEmpty || lineDiscount > gross || percent > 100) {
        throw invalidResponse();
      }

      final promotionId = asStr(promotion['promotionId']);

      pricedLines.add(
        QuoteLine(
          sku: sku,
          name: asStr(row['productName']),
          qty: quantity.toInt(),
          unitPrice: unitPrice,
          grossAmount: gross,
          discount: lineDiscount,
          promoId: promotionId,
          promoName: asStr(promotion['name']),
          pct: percent,
        ),
      );

      total += gross;
      discount += lineDiscount;

      if (promotionId.isNotEmpty && lineDiscount > 0) {
        names[promotionId] = asStr(promotion['name']);
        amounts.update(
          promotionId,
          (amount) => amount + lineDiscount,
          ifAbsent: () => lineDiscount,
        );
        details
            .putIfAbsent(promotionId, () => <String>[])
            .add('$sku × ${quantity.toInt()}');
      }
    }

    return PriceQuote(
      lines: pricedLines,
      applied: amounts.entries
          .map(
            (entry) => AppliedPromo(
              id: entry.key,
              name: names[entry.key] ?? '',
              typeLabel: 'Khuyến mãi số lượng',
              detail: details[entry.key]!.join(' + '),
              amount: entry.value,
            ),
          )
          .toList(),
      total: total,
      discount: discount,
    );
  }
}
