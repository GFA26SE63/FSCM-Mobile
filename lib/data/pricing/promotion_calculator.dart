import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';

/// Pure promotion pricing, used in two places:
///
/// * offline: the Sales app estimates the discount from the promotions
///   cached in LocalPromotion (the server result stays final);
/// Rules (prototype + SPEC): every line receives at most ONE promotion -
/// the one with the highest percentage. Type 1 promotions test the line
/// quantity, type 2 promotions test the combined quantity of the group.
class PromotionCalculator {
  PromotionCalculator._();

  static PriceQuote quote({
    required List<CartLine> lines,
    required String retailerCode,
    required List<Promotion> promotions,
    required Map<String, Product> products,
    Map<String, int> prices = const <String, int>{},
    DateTime? now,
  }) {
    final at = now ?? AppClock.now();
    final usable = promotions
        .where((p) => p.isRunning(at) && p.appliesTo(retailerCode))
        .toList();

    int qtyOf(String sku) =>
        lines.where((l) => l.sku == sku).fold<int>(0, (s, l) => s + l.qty);

    final quoteLines = <QuoteLine>[];
    final applied = <String, _Acc>{};
    var total = 0;
    var discount = 0;

    for (final l in lines) {
      final product = products[l.sku];
      final unit = prices[l.sku] ?? product?.basePrice ?? 0;
      final base = unit * l.qty;

      Promotion? bestPromo;
      double bestPct = 0;
      for (final p in usable) {
        double pct = 0;
        if (p.type == 1) {
          for (final r in p.rules) {
            if (r.sku == l.sku && l.qty >= r.minQty) pct = r.pct;
          }
        } else if (p.type == 2 && p.groupSkus.contains(l.sku)) {
          final groupQty = p.groupSkus.fold<int>(0, (s, k) => s + qtyOf(k));
          if (groupQty >= p.groupMinQty) pct = p.groupPct;
        }
        if (pct > bestPct) {
          bestPct = pct;
          bestPromo = p;
        }
      }

      final disc = bestPromo == null ? 0 : (base * bestPct / 100).round();
      total += base;
      discount += disc;
      quoteLines.add(QuoteLine(
        sku: l.sku,
        name: product?.name ?? l.sku,
        qty: l.qty,
        unitPrice: unit,
        discount: disc,
        promoId: bestPromo?.id ?? '',
        promoName: bestPromo?.name ?? '',
        pct: bestPromo == null ? 0 : bestPct,
      ));
      if (bestPromo != null && disc > 0) {
        final acc = applied.putIfAbsent(bestPromo.id, () => _Acc(bestPromo!));
        acc.parts.add('${l.sku} × ${l.qty} (−${_pct(bestPct)}%)');
        acc.amount += disc;
      }
    }

    return PriceQuote(
      lines: quoteLines,
      applied: applied.values
          .map((a) => AppliedPromo(
                id: a.promo.id,
                name: a.promo.name,
                typeLabel: a.promo.typeLabel,
                detail: a.parts.join(', '),
                amount: a.amount,
              ))
          .toList(),
      total: total,
      discount: discount,
    );
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}

class _Acc {
  _Acc(this.promo);
  final Promotion promo;
  final List<String> parts = <String>[];
  int amount = 0;
}
