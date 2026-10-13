import 'package:fscm_mobile/data/models/json_utils.dart';

/// One priced line of a quote (local estimate or `POST /pricing/quote`).
class QuoteLine {
  const QuoteLine({
    required this.sku,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    this.promoId = '',
    this.promoName = '',
    this.pct = 0,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
        sku: asStr(j['sku']),
        name: asStr(j['name']),
        qty: asInt(j['qty']),
        unitPrice: asInt(j['unitPrice']),
        discount: asInt(j['discount']),
        promoId: asStr(j['promoId']),
        promoName: asStr(j['promoName']),
        pct: asDouble(j['pct']),
      );

  final String sku;
  final String name;
  final int qty;
  final int unitPrice;
  final int discount;
  final String promoId;
  final String promoName;
  final double pct;

  int get base => qty * unitPrice;
  bool get hasDiscount => discount > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sku': sku,
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
        'discount': discount,
        'promoId': promoId,
        'promoName': promoName,
        'pct': pct,
      };
}

/// A promotion that contributed to the quote (grouped for the summary card).
class AppliedPromo {
  const AppliedPromo({
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.detail,
    required this.amount,
  });

  factory AppliedPromo.fromJson(Map<String, dynamic> j) => AppliedPromo(
        id: asStr(j['id']),
        name: asStr(j['name']),
        typeLabel: asStr(j['typeLabel']),
        detail: asStr(j['detail']),
        amount: asInt(j['amount']),
      );

  final String id;
  final String name;
  final String typeLabel;
  final String detail;
  final int amount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'typeLabel': typeLabel,
        'detail': detail,
        'amount': amount,
      };
}

class PriceQuote {
  const PriceQuote({
    required this.lines,
    required this.applied,
    required this.total,
    required this.discount,
  });

  factory PriceQuote.fromJson(Map<String, dynamic> j) => PriceQuote(
        lines: mapList(j['lines'], QuoteLine.fromJson),
        applied: mapList(j['applied'], AppliedPromo.fromJson),
        total: asInt(j['total']),
        discount: asInt(j['discount']),
      );

  static const PriceQuote empty = PriceQuote(
      lines: <QuoteLine>[], applied: <AppliedPromo>[], total: 0, discount: 0);

  final List<QuoteLine> lines;
  final List<AppliedPromo> applied;
  final int total;
  final int discount;

  int get finalAmount => total - discount;
  bool get hasPromo => applied.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lines': lines.map((l) => l.toJson()).toList(),
        'applied': applied.map((a) => a.toJson()).toList(),
        'total': total,
        'discount': discount,
      };
}
