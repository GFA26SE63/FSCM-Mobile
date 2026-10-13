import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Per-SKU rule of a type-1 promotion: from [minQty] cartons give [pct] %.
class PromoRule {
  const PromoRule({required this.sku, required this.minQty, required this.pct});

  factory PromoRule.fromJson(Map<String, dynamic> j) => PromoRule(
        sku: asStr(j['sku']),
        minQty: asInt(j['minQty']),
        pct: asDouble(j['pct']),
      );

  final String sku;
  final int minQty;
  final double pct;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'sku': sku, 'minQty': minQty, 'pct': pct};
}

/// Promotion KM-000. Type 1 = per SKU, type 2 = per product group
/// (the combined quantity of [groupSkus] must reach [groupMinQty]).
class Promotion {
  const Promotion({
    required this.id,
    required this.name,
    required this.type,
    this.validFrom,
    this.validTo,
    this.active = true,
    this.retailerCodes,
    this.rules = const <PromoRule>[],
    this.groupSkus = const <String>[],
    this.groupMinQty = 0,
    this.groupPct = 0,
  });

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
        id: asStr(j['id']),
        name: asStr(j['name']),
        type: asInt(j['type'], 1),
        validFrom: asDate(j['validFrom']),
        validTo: asDate(j['validTo']),
        active: asBool(j['active'], true),
        retailerCodes:
            j['retailerCodes'] == null ? null : asStrList(j['retailerCodes']),
        rules: mapList(j['rules'], PromoRule.fromJson),
        groupSkus: asStrList(j['groupSkus']),
        groupMinQty: asInt(j['groupMinQty']),
        groupPct: asDouble(j['groupPct']),
      );

  final String id;
  final String name;
  final int type;
  final DateTime? validFrom;
  final DateTime? validTo;
  final bool active;

  /// null = every retailer.
  final List<String>? retailerCodes;
  final List<PromoRule> rules;
  final List<String> groupSkus;
  final int groupMinQty;
  final double groupPct;

  String get typeLabel =>
      type == 1 ? 'Loại 1 · theo từng SKU' : 'Loại 2 · theo nhóm sản phẩm';

  String get validText {
    if (validFrom == null && validTo == null) return 'Không giới hạn';
    return '${AppDates.dayMonth(validFrom)} – ${AppDates.date(validTo)}';
  }

  bool isRunning(DateTime now) {
    if (!active) return false;
    final today = DateTime(now.year, now.month, now.day);
    if (validFrom != null && today.isBefore(validFrom!)) return false;
    if (validTo != null && today.isAfter(validTo!)) return false;
    return true;
  }

  bool appliesTo(String retailerCode) =>
      retailerCodes == null || retailerCodes!.contains(retailerCode);

  /// Human readable condition, e.g. `SKU001 từ 50 thùng giảm 5%`.
  List<String> get conditionLines {
    if (type == 1) {
      return rules
          .map((r) => '${r.sku} từ ${r.minQty} thùng giảm ${_pct(r.pct)}%')
          .toList();
    }
    return <String>[
      '${groupSkus.join(' + ')} tổng từ $groupMinQty thùng giảm ${_pct(groupPct)}%',
    ];
  }

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type,
        'validFrom': isoOrNull(validFrom),
        'validTo': isoOrNull(validTo),
        'active': active,
        'retailerCodes': retailerCodes,
        'rules': rules.map((r) => r.toJson()).toList(),
        'groupSkus': groupSkus,
        'groupMinQty': groupMinQty,
        'groupPct': groupPct,
      };
}
