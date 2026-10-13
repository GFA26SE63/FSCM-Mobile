import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';

/// Retailer registration request `KB-0000` declared by Sales.
class RetailerRegistration {
  const RetailerRegistration({
    required this.code,
    required this.name,
    required this.address,
    required this.contactName,
    required this.phone,
    required this.areaName,
    required this.status,
    required this.potential,
    this.retailerCode = '',
    this.reason = '',
    this.timeline = const <TimelineEntry>[],
  });

  factory RetailerRegistration.fromJson(Map<String, dynamic> j) =>
      RetailerRegistration(
        code: asStr(j['code']),
        name: asStr(j['name']),
        address: asStr(j['address']),
        contactName: asStr(j['contactName']),
        phone: asStr(j['phone']),
        areaName: asStr(j['areaName']),
        status: RegistrationStatus.fromCode(asStrOrNull(j['status'])),
        potential: RetailerPotential.fromJson(asMap(j['potential'])),
        retailerCode: asStr(j['retailerCode']),
        reason: asStr(j['reason']),
        timeline: mapList(j['timeline'], TimelineEntry.fromJson),
      );

  final String code;
  final String name;
  final String address;
  final String contactName;
  final String phone;
  final String areaName;
  final RegistrationStatus status;
  final RetailerPotential potential;

  /// 8-digit code assigned on approval.
  final String retailerCode;
  final String reason;
  final List<TimelineEntry> timeline;
}

/// Request body of `POST /retailer-registrations`.
class NewRegistration {
  const NewRegistration({
    required this.name,
    required this.address,
    required this.contactName,
    required this.phone,
    required this.potential,
  });

  final String name;
  final String address;
  final String contactName;
  final String phone;
  final RetailerPotential potential;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'address': address,
        'contactName': contactName,
        'phone': phone,
        'potential': potential.toJson(),
      };
}
