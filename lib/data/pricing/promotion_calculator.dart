import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/price_quote.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';

class PromotionCalculator {
  PromotionCalculator._();

  static PriceQuote quote({
    required List<CartLine> lines,
    required String retailerCode,
    required List<Promotion> promotions,
    required Map<String, Product> products,
    Map<String, num> prices = const <String, num>{},
    Map<String, String> promotionCodes = const <String, String>{},
    DateTime? now,
  }) {
    final at = now ?? AppClock.now();
    final quantities = <String, int>{};

    for (final line in lines) {
      if (line.qty <= 0) {
        throw ArgumentError('Số lượng đặt hàng phải lớn hơn 0.');
      }

      quantities.update(
        line.sku,
        (quantity) => quantity + line.qty,
        ifAbsent: () => line.qty,
      );
    }

    final usable = promotions
        .where(
          (promotion) =>
              promotion.isRunning(at) && promotion.appliesTo(retailerCode),
        )
        .toList()
      ..sort(
        (a, b) => (promotionCodes[a.id] ?? a.id)
            .compareTo(promotionCodes[b.id] ?? b.id),
      );

    final resultLines = <QuoteLine>[];
    final missing = <String>[];
    final applied = <String, _AppliedAccumulator>{};

    var total = 0;
    var discount = 0;

    for (final entry in quantities.entries) {
      final sku = entry.key;
      final quantity = entry.value;
      final product = products[sku];
      final unitPrice = prices[sku];

      if (product == null ||
          unitPrice == null ||
          !unitPrice.isFinite ||
          unitPrice < 0) {
        missing.add(sku);
        continue;
      }

      Promotion? best;
      var bestPercent = 0.0;

      for (final promotion in usable) {
        var percent = 0.0;

        if (promotion.type == 1) {
          for (final rule in promotion.rules) {
            if (rule.sku == sku &&
                quantity >= rule.minQty &&
                rule.pct > percent) {
              percent = rule.pct;
            }
          }
        } else if (promotion.type == 2 && promotion.groupSkus.contains(sku)) {
          final groupQuantity = promotion.groupSkus.toSet().fold<int>(
                0,
                (sum, groupSku) => sum + (quantities[groupSku] ?? 0),
              );

          if (groupQuantity >= promotion.groupMinQty) {
            percent = promotion.groupPct;
          }
        }

        if (!percent.isFinite || percent < 0 || percent > 100) {
          continue;
        }

        // usable đã được sắp theo mã:
        // cùng phần trăm thì giữ chương trình đầu tiên.
        if (percent > bestPercent) {
          best = promotion;
          bestPercent = percent;
        }
      }

      final gross = (unitPrice * quantity).round();
      final lineDiscount = (gross * bestPercent / 100).round();

      total += gross;
      discount += lineDiscount;

      resultLines.add(
        QuoteLine(
          sku: sku,
          name: product.name,
          qty: quantity,
          unitPrice: unitPrice,
          grossAmount: gross,
          discount: lineDiscount,
          promoId: best?.id ?? '',
          promoName: best?.name ?? '',
          pct: bestPercent,
        ),
      );

      if (best != null && lineDiscount > 0) {
        final promotion = best;
        final accumulator = applied.putIfAbsent(
          promotion.id,
          () => _AppliedAccumulator(promotion),
        );

        accumulator.amount += lineDiscount;
        accumulator.parts.add('$sku × $quantity');
      }
    }

    return PriceQuote(
      lines: resultLines,
      applied: applied.values
          .map(
            (value) => AppliedPromo(
              id: value.promotion.id,
              name: value.promotion.name,
              typeLabel: value.promotion.typeLabel,
              detail: value.parts.join(' + '),
              amount: value.amount,
            ),
          )
          .toList(),
      total: total,
      discount: discount,
      missingPriceSkus: missing,
    );
  }
}

class _AppliedAccumulator {
  _AppliedAccumulator(this.promotion);

  final Promotion promotion;
  final List<String> parts = [];
  int amount = 0;
}
