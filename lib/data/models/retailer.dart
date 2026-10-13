import 'package:fscm_mobile/data/models/json_utils.dart';

/// Retailer (điểm bán). `code` is the 8-digit customer code.
class Retailer {
  const Retailer({
    required this.code,
    required this.name,
    required this.address,
    required this.areaCode,
    required this.areaName,
    this.region = '',
    this.creditTerm = 0,
    this.tier = 'Thành viên',
    this.points = 0,
    this.phone = '',
    this.contactName = '',
  });

  factory Retailer.fromJson(Map<String, dynamic> j) => Retailer(
        code: asStr(j['code']),
        name: asStr(j['name']),
        address: asStr(j['address']),
        areaCode: asStr(j['areaCode']),
        areaName: asStr(j['areaName']),
        region: asStr(j['region']),
        creditTerm: asInt(j['creditTerm']),
        tier: asStr(j['tier'], 'Thành viên'),
        points: asInt(j['points']),
        phone: asStr(j['phone']),
        contactName: asStr(j['contactName']),
      );

  final String code;
  final String name;
  final String address;
  final String areaCode;
  final String areaName;
  final String region;

  /// Allowed credit term in days: 0 (none), 7, 14 or 30.
  final int creditTerm;
  final String tier;
  final int points;
  final String phone;
  final String contactName;

  bool get creditAllowed => creditTerm > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name': name,
        'address': address,
        'areaCode': areaCode,
        'areaName': areaName,
        'region': region,
        'creditTerm': creditTerm,
        'tier': tier,
        'points': points,
        'phone': phone,
        'contactName': contactName,
      };
}

/// "Đánh giá tiềm năng" fields sent with a new retailer declaration.
class RetailerPotential {
  const RetailerPotential({
    this.kind = 'Tạp hóa',
    this.size = 'S',
    this.areaM2 = 0,
    this.fridges = 0,
    this.forecastRevenue = 0,
    this.capacityCases = 0,
    this.frequency = '1 lần/tuần',
    this.grade = '',
  });

  factory RetailerPotential.fromJson(Map<String, dynamic> j) =>
      RetailerPotential(
        kind: asStr(j['kind'], 'Tạp hóa'),
        size: asStr(j['size'], 'S'),
        areaM2: asInt(j['areaM2']),
        fridges: asInt(j['fridges']),
        forecastRevenue: asInt(j['forecastRevenue']),
        capacityCases: asInt(j['capacityCases']),
        frequency: asStr(j['frequency'], '1 lần/tuần'),
        grade: asStr(j['grade']),
      );

  final String kind;
  final String size;
  final int areaM2;
  final int fridges;

  /// Forecast revenue per month (đ).
  final int forecastRevenue;

  /// Purchasing capacity, cartons per month.
  final int capacityCases;
  final String frequency;

  /// Assigned by Operator on approval (A/B/C).
  final String grade;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'size': size,
        'areaM2': areaM2,
        'fridges': fridges,
        'forecastRevenue': forecastRevenue,
        'capacityCases': capacityCases,
        'frequency': frequency,
        'grade': grade,
      };
}
