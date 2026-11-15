import 'package:fscm_mobile/data/models/json_utils.dart';

/// Retailer (điểm bán). `code` is the customer code; `id` is the backend ID.
class Retailer {
  const Retailer({
    this.id = '',
    required this.code,
    required this.name,
    required this.address,
    required this.areaCode,
    required this.areaName,
    this.status = '',
    this.region = '',
    this.creditTerm = 0,
    this.creditLimit = 0,
    this.tier = 'Thành viên',
    this.points = 0,
    this.phone = '',
    this.contactName = '',
  });

  factory Retailer.fromJson(Map<String, dynamic> json) => Retailer(
        id: asStr(json['id']),
        code: asStr(json['code']),
        name: asStr(json['name']),
        address: asStr(json['address']),
        areaCode: asStr(json['areaCode'] ?? json['regionCode']),
        areaName: asStr(json['areaName'] ?? json['regionName']),
        status: asStr(json['status']),
        region: asStr(json['region']),
        creditTerm: asInt(json['creditTermDays'] ?? json['creditTerm']),
        creditLimit: asDouble(json['creditLimit']),
        tier: asStr(json['tier'], 'Thành viên'),
        points: asInt(json['points']),
        phone: asStr(json['phone']),
        contactName: asStr(json['contactName']),
      );

  final String id;
  final String code;
  final String name;
  final String address;

  // Compatibility fields. Do not use these to authorize Sales orders.
  final String areaCode;
  final String areaName;
  final String region;

  final String status;
  final int creditTerm;
  final double creditLimit;
  final String tier;
  final int points;
  final String phone;
  final String contactName;

  bool get creditAllowed => creditTerm > 0;

  String get statusLabel => switch (status) {
        'Draft' => 'Bản nháp',
        'PendingApproval' => 'Chờ duyệt',
        'Active' => 'Đang hoạt động',
        'Rejected' => 'Bị từ chối',
        'Inactive' => 'Ngừng hoạt động',
        '' => 'Chưa có trạng thái',
        _ => status,
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
        'address': address,
        'areaCode': areaCode,
        'areaName': areaName,
        'status': status,
        'region': region,
        'creditTerm': creditTerm,
        'creditLimit': creditLimit,
        'tier': tier,
        'points': points,
        'phone': phone,
        'contactName': contactName,
      };
}

/// Potential information used by existing declaration screens.
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

  factory RetailerPotential.fromJson(Map<String, dynamic> json) =>
      RetailerPotential(
        kind: asStr(json['kind'], 'Tạp hóa'),
        size: asStr(json['size'], 'S'),
        areaM2: asInt(json['areaM2']),
        fridges: asInt(json['fridges']),
        forecastRevenue: asInt(json['forecastRevenue']),
        capacityCases: asInt(json['capacityCases']),
        frequency: asStr(json['frequency'], '1 lần/tuần'),
        grade: asStr(json['grade']),
      );

  final String kind;
  final String size;
  final int areaM2;
  final int fridges;
  final int forecastRevenue;
  final int capacityCases;
  final String frequency;
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
