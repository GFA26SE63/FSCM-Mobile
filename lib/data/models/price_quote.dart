import 'package:fscm_mobile/data/models/json_utils.dart';

class QuoteLine {
  const QuoteLine({
    required this.sku,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    this.grossAmount,
    this.promoId = '',
    this.promoName = '',
    this.pct = 0,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        sku: asStr(json['sku']),
        name: asStr(json['name']),
        qty: asInt(json['qty']),
        unitPrice: asDouble(json['unitPrice']),
        grossAmount:
            json['grossAmount'] == null ? null : asInt(json['grossAmount']),
        discount: asInt(json['discount']),
        promoId: asStr(json['promoId']),
        promoName: asStr(json['promoName']),
        pct: asDouble(json['pct']),
      );

  final String sku;
  final String name;
  final int qty;
  final num unitPrice;
  final int? grossAmount;
  final int discount;
  final String promoId;
  final String promoName;
  final double pct;

  int get base => grossAmount ?? (qty * unitPrice).round();
  int get net => base - discount;
  bool get hasDiscount => discount > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sku': sku,
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
        'grossAmount': base,
        'discount': discount,
        'promoId': promoId,
        'promoName': promoName,
        'pct': pct,
      };
}

class AppliedPromo {
  const AppliedPromo({
    required this.id,
    required this.name,
    required this.typeLabel,
    required this.detail,
    required this.amount,
  });

  factory AppliedPromo.fromJson(Map<String, dynamic> json) => AppliedPromo(
        id: asStr(json['id']),
        name: asStr(json['name']),
        typeLabel: asStr(json['typeLabel']),
        detail: asStr(json['detail']),
        amount: asInt(json['amount']),
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
    this.missingPriceSkus = const <String>[],
  });

  factory PriceQuote.fromJson(Map<String, dynamic> json) => PriceQuote(
        lines: mapList(json['lines'], QuoteLine.fromJson),
        applied: mapList(json['applied'], AppliedPromo.fromJson),
        total: asInt(json['total']),
        discount: asInt(json['discount']),
        missingPriceSkus: asStrList(json['missingPriceSkus']),
      );

  static const PriceQuote empty = PriceQuote(
    lines: <QuoteLine>[],
    applied: <AppliedPromo>[],
    total: 0,
    discount: 0,
  );

  final List<QuoteLine> lines;
  final List<AppliedPromo> applied;

  /// Tổng của các dòng đã có giá.
  /// Không hiển thị như tổng giỏ hàng nếu isComplete=false.
  final int total;
  final int discount;
  final List<String> missingPriceSkus;

  bool get isComplete => missingPriceSkus.isEmpty;
  int get finalAmount => total - discount;
  bool get hasPromo => applied.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lines': lines.map((line) => line.toJson()).toList(),
        'applied': applied.map((promo) => promo.toJson()).toList(),
        'total': total,
        'discount': discount,
        'missingPriceSkus': missingPriceSkus,
      };
}
