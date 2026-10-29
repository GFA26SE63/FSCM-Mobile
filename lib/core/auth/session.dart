import 'package:fscm_mobile/core/auth/user_role.dart';

/// Single labeled scope entity matching `ScopeLabel` in `apiv1.json`.
class ScopeLabel {
  const ScopeLabel({required this.id, required this.code, required this.name});

  factory ScopeLabel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScopeLabel(id: '', code: '', name: '');
    return ScopeLabel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  final String id;
  final String code;
  final String name;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'code': code,
        'name': name,
      };
}

/// Labeled scopes matching `IdentityScopeLabels` in `apiv1.json`.
class UserScopeLabels {
  const UserScopeLabels({
    this.warehouses = const <ScopeLabel>[],
    this.regions = const <ScopeLabel>[],
    this.salesGroups = const <ScopeLabel>[],
    this.retailers = const <ScopeLabel>[],
  });

  factory UserScopeLabels.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserScopeLabels();
    List<ScopeLabel> listOf(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ScopeLabel.fromJson(e.cast<String, dynamic>()))
            .where((l) =>
                l.id.isNotEmpty || l.code.isNotEmpty || l.name.isNotEmpty)
            .toList();
      }
      return const <ScopeLabel>[];
    }

    return UserScopeLabels(
      warehouses: listOf('warehouses'),
      regions: listOf('regions'),
      salesGroups: listOf('salesGroups'),
      retailers: listOf('retailers'),
    );
  }

  final List<ScopeLabel> warehouses;
  final List<ScopeLabel> regions;
  final List<ScopeLabel> salesGroups;
  final List<ScopeLabel> retailers;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'warehouses': warehouses.map((e) => e.toJson()).toList(),
        'regions': regions.map((e) => e.toJson()).toList(),
        'salesGroups': salesGroups.map((e) => e.toJson()).toList(),
        'retailers': retailers.map((e) => e.toJson()).toList(),
      };
}

/// Scope IDs returned by `/api/v1/auth/login`, `/api/v1/auth/refresh`, and
/// `/api/v1/auth/me` (`IdentityScope` in `apiv1.json`).
class UserScope {
  const UserScope({
    this.warehouseIds = const <String>[],
    this.salesGroupIds = const <String>[],
    this.regionIds = const <String>[],
    this.retailerIds = const <String>[],
  });

  factory UserScope.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserScope();
    List<String> listOf(String key) {
      final raw = json[key];
      if (raw is List) {
        return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      return const <String>[];
    }

    return UserScope(
      warehouseIds: listOf('warehouseIds'),
      salesGroupIds: listOf('salesGroupIds'),
      regionIds: listOf('regionIds'),
      retailerIds: listOf('retailerIds'),
    );
  }

  final List<String> warehouseIds;
  final List<String> salesGroupIds;
  final List<String> regionIds;
  final List<String> retailerIds;

  bool hasWarehouse(String id) => warehouseIds.contains(id);
  bool hasSalesGroup(String id) => salesGroupIds.contains(id);
  bool hasRegion(String id) => regionIds.contains(id);
  bool hasRetailer(String id) => retailerIds.contains(id);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'warehouseIds': warehouseIds,
        'salesGroupIds': salesGroupIds,
        'regionIds': regionIds,
        'retailerIds': retailerIds,
      };
}

/// Signed-in user matching `AuthenticatedUser` in `apiv1.json`.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.email = '',
    this.phone = '',
    this.isActive = true,
    this.mustChangePassword = false,
    this.scope = const UserScope(),
    this.scopeLabels = const UserScopeLabels(),
    this.areaCode,
    this.areaName,
    this.salesGroup,
    this.warehouseCode,
    this.warehouseName,
    this.retailerCode,
    this.retailerName,
    this.retailerAddress,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final scopeMap = (json['scope'] as Map?)?.cast<String, dynamic>();
    final parsedScope = UserScope.fromJson(scopeMap);
    final labelsMap = (json['scopeLabels'] as Map?)?.cast<String, dynamic>();
    final parsedLabels = UserScopeLabels.fromJson(labelsMap);

    return AppUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: UserRole.fromCode(json['role']?.toString()),
      isActive: (json['isActive'] as bool?) ?? true,
      mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
      scope: parsedScope,
      scopeLabels: parsedLabels,
      areaCode: json['areaCode']?.toString(),
      areaName: json['areaName']?.toString(),
      salesGroup: json['salesGroup']?.toString(),
      warehouseCode: json['warehouseCode']?.toString(),
      warehouseName: json['warehouseName']?.toString(),
      retailerCode: json['retailerCode']?.toString(),
      retailerName: json['retailerName']?.toString(),
      retailerAddress: json['retailerAddress']?.toString(),
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final bool mustChangePassword;
  final UserScope scope;
  final UserScopeLabels scopeLabels;
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
        final group = scopeLabels.salesGroups.isNotEmpty
            ? scopeLabels.salesGroups.first.name
            : salesGroup ??
                (scope.salesGroupIds.isNotEmpty
                    ? scope.salesGroupIds.first
                    : '—');
        final area = scopeLabels.regions.isNotEmpty
            ? scopeLabels.regions.first.name
            : areaName ??
                areaCode ??
                (scope.regionIds.isNotEmpty ? scope.regionIds.first : '—');
        return 'Nhóm $group · Khu vực $area';
      case UserRole.warehouseKeeper:
        if (scopeLabels.warehouses.isNotEmpty) {
          final wh = scopeLabels.warehouses.first;
          return '${wh.name} (${wh.code})';
        }
        final whCode = warehouseCode ??
            (scope.warehouseIds.isNotEmpty ? scope.warehouseIds.first : '—');
        if (warehouseName != null && warehouseName!.isNotEmpty) {
          return '$warehouseName ($whCode)';
        }
        return 'Kho $whCode';
      case UserRole.retailer:
        if (scopeLabels.retailers.isNotEmpty) {
          final rt = scopeLabels.retailers.first;
          return '${rt.name} (${rt.code})';
        }
        final rtCode = retailerCode ??
            (scope.retailerIds.isNotEmpty ? scope.retailerIds.first : '—');
        return 'Mã $rtCode';
      default:
        return role.label;
    }
  }

  bool canAccessWarehouse(String warehouseIdOrCode) {
    if (role != UserRole.warehouseKeeper) return false;
    if (warehouseCode != null && warehouseCode == warehouseIdOrCode) {
      return true;
    }
    if (scope.warehouseIds.contains(warehouseIdOrCode)) return true;
    return scopeLabels.warehouses.any((w) =>
        w.id == warehouseIdOrCode ||
        w.code.toUpperCase() == warehouseIdOrCode.toUpperCase());
  }

  bool canAccessSalesGroup(String salesGroupIdOrCode) {
    if (role != UserRole.sales) return false;
    if (salesGroup != null && salesGroup == salesGroupIdOrCode) return true;
    if (scope.salesGroupIds.contains(salesGroupIdOrCode)) return true;
    return scopeLabels.salesGroups.any((g) =>
        g.id == salesGroupIdOrCode ||
        g.code.toUpperCase() == salesGroupIdOrCode.toUpperCase());
  }

  bool canAccessRegion(String regionIdOrCode) {
    if (role != UserRole.sales) return false;
    if (areaCode != null && areaCode == regionIdOrCode) return true;
    if (scope.regionIds.contains(regionIdOrCode)) return true;
    return scopeLabels.regions.any((r) =>
        r.id == regionIdOrCode ||
        r.code.toUpperCase() == regionIdOrCode.toUpperCase());
  }

  bool canAccessRetailer(String retailerIdOrCode) {
    if (role == UserRole.retailer) {
      if (retailerCode != null && retailerCode == retailerIdOrCode) return true;
      if (scope.retailerIds.contains(retailerIdOrCode)) return true;
      return scopeLabels.retailers.any((rt) =>
          rt.id == retailerIdOrCode ||
          rt.code.toUpperCase() == retailerIdOrCode.toUpperCase());
    }
    if (role == UserRole.sales) {
      if (scope.retailerIds.isEmpty && scopeLabels.retailers.isEmpty) {
        return true;
      }
      if (scope.retailerIds.contains(retailerIdOrCode)) return true;
      return scopeLabels.retailers.any((rt) =>
          rt.id == retailerIdOrCode ||
          rt.code.toUpperCase() == retailerIdOrCode.toUpperCase());
    }
    return false;
  }

  AppUser mergeProfile(AppUser fresh) => AppUser(
        id: fresh.id.isNotEmpty ? fresh.id : id,
        fullName: fresh.fullName.isNotEmpty ? fresh.fullName : fullName,
        email: fresh.email.isNotEmpty ? fresh.email : email,
        phone: fresh.phone.isNotEmpty ? fresh.phone : phone,
        role: fresh.role,
        isActive: fresh.isActive,
        mustChangePassword: fresh.mustChangePassword,
        scope: fresh.scope.warehouseIds.isNotEmpty ||
                fresh.scope.salesGroupIds.isNotEmpty ||
                fresh.scope.regionIds.isNotEmpty ||
                fresh.scope.retailerIds.isNotEmpty
            ? fresh.scope
            : scope,
        scopeLabels: fresh.scopeLabels.warehouses.isNotEmpty ||
                fresh.scopeLabels.regions.isNotEmpty ||
                fresh.scopeLabels.salesGroups.isNotEmpty ||
                fresh.scopeLabels.retailers.isNotEmpty
            ? fresh.scopeLabels
            : scopeLabels,
        areaCode: fresh.areaCode ?? areaCode,
        areaName: fresh.areaName ?? areaName,
        salesGroup: fresh.salesGroup ?? salesGroup,
        warehouseCode: fresh.warehouseCode ?? warehouseCode,
        warehouseName: fresh.warehouseName ?? warehouseName,
        retailerCode: fresh.retailerCode ?? retailerCode,
        retailerName: fresh.retailerName ?? retailerName,
        retailerAddress: fresh.retailerAddress ?? retailerAddress,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'role': role.code,
        'isActive': isActive,
        'mustChangePassword': mustChangePassword,
        'scope': scope.toJson(),
        'scopeLabels': scopeLabels.toJson(),
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

/// Active session matching `AuthenticationResult` in `apiv1.json`.
class Session {
  const Session({
    required this.accessToken,
    required this.user,
    this.expiresAt,
    this.refreshToken,
    this.refreshTokenExpiresAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    final target = json.containsKey('accessToken')
        ? json
        : (json['data'] is Map
            ? (json['data'] as Map).cast<String, dynamic>()
            : (json['result'] is Map
                ? (json['result'] as Map).cast<String, dynamic>()
                : json));

    final accessExp = target['accessTokenExpiresAt']?.toString() ??
        target['expiresAt']?.toString() ??
        '';
    final refreshExp = target['refreshTokenExpiresAt']?.toString() ?? '';
    return Session(
      accessToken: target['accessToken']?.toString() ?? '',
      expiresAt: DateTime.tryParse(accessExp),
      refreshToken: target['refreshToken']?.toString(),
      refreshTokenExpiresAt: DateTime.tryParse(refreshExp),
      user: AppUser.fromJson(
        (target['user'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  final String accessToken;
  final DateTime? expiresAt;
  final String? refreshToken;
  final DateTime? refreshTokenExpiresAt;
  final AppUser user;

  DateTime? get accessTokenExpiresAt => expiresAt;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt!);
  }

  bool get isRefreshExpired {
    if (refreshTokenExpiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(refreshTokenExpiresAt!);
  }

  Session copyWith({
    String? accessToken,
    DateTime? expiresAt,
    String? refreshToken,
    DateTime? refreshTokenExpiresAt,
    AppUser? user,
  }) {
    return Session(
      accessToken: accessToken ?? this.accessToken,
      expiresAt: expiresAt ?? this.expiresAt,
      refreshToken: refreshToken ?? this.refreshToken,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        if (expiresAt != null)
          'accessTokenExpiresAt': expiresAt!.toIso8601String(),
        if (refreshToken != null) 'refreshToken': refreshToken,
        if (refreshTokenExpiresAt != null)
          'refreshTokenExpiresAt': refreshTokenExpiresAt!.toIso8601String(),
        'user': user.toJson(),
      };
}
