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
    this.email = '',
    this.areaCode,
    this.areaName,
    this.salesGroup,
    this.warehouseCode,
    this.warehouseName,
    this.retailerCode,
    this.retailerName,
    this.retailerAddress,
    this.regionIds = const <String>[],
    this.salesGroupIds = const <String>[],
    this.regionLabels = const <ScopeLabel>[],
    this.salesGroupLabels = const <ScopeLabel>[],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    // Backend `AuthenticatedUser`: { scope: {regionIds, salesGroupIds, ...},
    // scopeLabels: {regions: [{id, code, name}], salesGroups: [...]} }.
    final scope = _map(json['scope']);
    final labels = _map(json['scopeLabels']);
    final regions = ScopeLabel.listFrom(labels['regions']);
    final groups = ScopeLabel.listFrom(labels['salesGroups']);
    return AppUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['email']?.toString() ?? '',
      role: UserRole.fromCode(json['role']?.toString()),
      areaCode: json['areaCode'] as String? ??
          (regions.isEmpty ? null : regions.first.code),
      areaName: json['areaName'] as String? ??
          (regions.isEmpty ? null : regions.first.name),
      salesGroup: json['salesGroup'] as String? ??
          (groups.isEmpty ? null : groups.first.code),
      warehouseCode: json['warehouseCode'] as String?,
      warehouseName: json['warehouseName'] as String?,
      retailerCode: json['retailerCode'] as String?,
      retailerName: json['retailerName'] as String?,
      retailerAddress: json['retailerAddress'] as String?,
      regionIds: _strings(scope['regionIds']),
      salesGroupIds: _strings(scope['salesGroupIds']),
      regionLabels: regions,
      salesGroupLabels: groups,
    );
  }

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
  static List<String> _strings(Object? v) =>
      v is List ? v.map((e) => e.toString()).toList() : const <String>[];

  final String id;
  final String fullName;
  final String email;
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

  /// Territory scope from the backend (Guid strings).
  final List<String> regionIds;
  final List<String> salesGroupIds;
  final List<ScopeLabel> regionLabels;
  final List<ScopeLabel> salesGroupLabels;

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
        'email': email,
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
        // Persisted in the backend shape so [AppUser.fromJson] reads it back.
        'scope': <String, dynamic>{
          'regionIds': regionIds,
          'salesGroupIds': salesGroupIds,
        },
        'scopeLabels': <String, dynamic>{
          'regions': regionLabels.map((e) => e.toJson()).toList(),
          'salesGroups': salesGroupLabels.map((e) => e.toJson()).toList(),
        },
      };
}

/// `{id, code, name}` entry of `scopeLabels`.
class ScopeLabel {
  const ScopeLabel({required this.id, required this.code, required this.name});

  factory ScopeLabel.fromJson(Map<String, dynamic> json) => ScopeLabel(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  static List<ScopeLabel> listFrom(Object? v) => v is List
      ? v
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => ScopeLabel.fromJson(e.cast<String, dynamic>()))
          .toList()
      : const <ScopeLabel>[];

  final String id;
  final String code;
  final String name;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'code': code, 'name': name};
}

class Session {
  const Session(
      {required this.accessToken,
      required this.user,
      this.refreshToken = '',
      this.expiresAt,
      this.refreshTokenExpiresAt});

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        accessToken: json['accessToken']?.toString() ?? '',
        refreshToken: json['refreshToken']?.toString() ?? '',
        expiresAt: DateTime.tryParse(
          json['expiresAt']?.toString() ??
              json['accessTokenExpiresAt']?.toString() ??
              '',
        ),
        refreshTokenExpiresAt:
            DateTime.tryParse(json['refreshTokenExpiresAt']?.toString() ?? ''),
        user: AppUser.fromJson(
          (json['user'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{},
        ),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
  final DateTime? refreshTokenExpiresAt;
  final AppUser user;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isRefreshTokenExpired =>
      refreshTokenExpiresAt != null &&
      refreshTokenExpiresAt!.isBefore(DateTime.now());

  Session copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    DateTime? refreshTokenExpiresAt,
    AppUser? user,
  }) =>
      Session(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        refreshTokenExpiresAt:
            refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
        user: user ?? this.user,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
        'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
        'user': user.toJson(),
      };
}
