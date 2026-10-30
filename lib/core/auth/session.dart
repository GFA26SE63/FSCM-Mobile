import 'package:fscm_mobile/core/auth/user_role.dart';

/// Signed-in user as returned by `GET /me`. Scope fields depend on role:
/// Sales -> area + sales group, Warehouse Keeper -> warehouse,
/// Retailer -> retailer code.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.areaCode,
    this.areaName,
    this.salesGroup,
    this.warehouseCode,
    this.warehouseName,
    this.retailerCode,
    this.retailerName,
    this.retailerAddress,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        phone: json['phone']?.toString() ?? json['email']?.toString() ?? '',
        role: UserRole.fromCode(json['role']?.toString()),
        areaCode: json['areaCode'] as String?,
        areaName: json['areaName'] as String?,
        salesGroup: json['salesGroup'] as String?,
        warehouseCode: json['warehouseCode'] as String?,
        warehouseName: json['warehouseName'] as String?,
        retailerCode: json['retailerCode'] as String?,
        retailerName: json['retailerName'] as String?,
        retailerAddress: json['retailerAddress'] as String?,
      );

  final String id;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? areaCode;
  final String? areaName;
  final String? salesGroup;
  final String? warehouseCode;
  final String? warehouseName;
  final String? retailerCode;
  final String? retailerName;
  final String? retailerAddress;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[parts.length - 2].substring(0, 1) +
            parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Subtitle shown on profile/home, e.g. `Nhóm Q12-A · Khu vực Quận 12`.
  String get scopeText {
    switch (role) {
      case UserRole.sales:
        return 'Nhóm ${salesGroup ?? '—'} · Khu vực ${areaName ?? areaCode ?? '—'}';
      case UserRole.warehouseKeeper:
        return '${warehouseName ?? '—'} (${warehouseCode ?? '—'})';
      case UserRole.retailer:
        return 'Mã ${retailerCode ?? '—'}';
      default:
        return role.label;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'role': role.code,
        'areaCode': areaCode,
        'areaName': areaName,
        'salesGroup': salesGroup,
        'warehouseCode': warehouseCode,
        'warehouseName': warehouseName,
        'retailerCode': retailerCode,
        'retailerName': retailerName,
        'retailerAddress': retailerAddress,
      };
}

class Session {
  const Session(
      {required this.accessToken, required this.user, this.expiresAt});

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        accessToken: json['accessToken']?.toString() ?? '',
        expiresAt: DateTime.tryParse(
          json['expiresAt']?.toString() ??
              json['accessTokenExpiresAt']?.toString() ??
              '',
        ),
        user: AppUser.fromJson(
          (json['user'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
      );

  final String accessToken;
  final DateTime? expiresAt;
  final AppUser user;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'expiresAt': expiresAt?.toIso8601String(),
        'user': user.toJson(),
      };
}
