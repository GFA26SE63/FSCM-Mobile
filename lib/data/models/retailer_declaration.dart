import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// Backend `RetailerTypes` (exact, case-sensitive values).
enum RetailerTypeOption {
  groceryStore('GroceryStore', 'Tạp hóa'),
  miniSupermarket('MiniSupermarket', 'Siêu thị mini'),
  convenienceStore('ConvenienceStore', 'Cửa hàng tiện lợi'),
  marketStall('MarketStall', 'Sạp chợ');

  const RetailerTypeOption(this.code, this.label);

  final String code;
  final String label;

  static RetailerTypeOption fromCode(String? code) =>
      RetailerTypeOption.values.firstWhere((e) => e.code == code,
          orElse: () => RetailerTypeOption.groceryStore);
}

/// Backend `RetailerStatuses`.
enum DeclarationStatus {
  draft('Draft', 'Nháp', StatusTone.neutral),
  pendingApproval('PendingApproval', 'Chờ duyệt', StatusTone.info),
  active('Active', 'Đã duyệt', StatusTone.success),
  rejected('Rejected', 'Bị từ chối', StatusTone.danger),
  inactive('Inactive', 'Ngừng hoạt động', StatusTone.neutral);

  const DeclarationStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  /// Only Draft / Rejected declarations can be edited or (re)submitted.
  bool get isEditable =>
      this == DeclarationStatus.draft || this == DeclarationStatus.rejected;

  static DeclarationStatus fromCode(String? code) => DeclarationStatus.values
      .firstWhere((e) => e.code.toLowerCase() == (code ?? '').toLowerCase(),
          orElse: () => DeclarationStatus.draft);
}

/// Credit terms the backend accepts (`AllowedCreditTerms`).
const List<int> allowedCreditTermDays = <int>[0, 7, 14, 30];

/// One MLOR entry: exactly one of [productCategoryId] / [productId].
class MlorDeclaration {
  const MlorDeclaration({
    this.productCategoryId,
    this.productId,
    required this.minimumLifeRatio,
    this.minimumLifeHours,
    this.label = '',
  });

  factory MlorDeclaration.fromJson(Map<String, dynamic> j) {
    final isSku = asStr(j['scope']) == 'Sku';
    return MlorDeclaration(
      productCategoryId: asStrOrNull(j['productCategoryId']),
      productId: asStrOrNull(j['productId']),
      minimumLifeRatio: asDouble(j['minimumLifeRatio']),
      minimumLifeHours:
          j['minimumLifeHours'] == null ? null : asInt(j['minimumLifeHours']),
      label: isSku
          ? 'SKU ${asStr(j['productSku'])} · ${asStr(j['productName'])}'
          : 'Ngành hàng ${asStr(j['categoryCode'])} · ${asStr(j['categoryName'])}',
    );
  }

  final String? productCategoryId;
  final String? productId;

  /// 0 < ratio < 1.
  final double minimumLifeRatio;

  /// SKU scope only, 0..shelfLifeHours.
  final int? minimumLifeHours;

  /// Display only, not sent.
  final String label;

  bool get isSku => productId != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productCategoryId': productCategoryId,
        'productId': productId,
        'minimumLifeRatio': minimumLifeRatio,
        'minimumLifeHours': minimumLifeHours,
      };
}

/// Backend `RetailerDetails` as seen by the declaring Sales.
class RetailerDeclaration {
  const RetailerDeclaration({
    required this.id,
    required this.code,
    required this.name,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    required this.retailerType,
    required this.forecastRevenue,
    required this.storeSizeSquareMeters,
    required this.storeSizeCategory,
    required this.purchasingCapacity,
    required this.purchaseFrequencyPerMonth,
    required this.requestedCreditTermDays,
    required this.creditTermDays,
    required this.potentialClass,
    required this.assessmentNote,
    required this.salesGroupCode,
    required this.reviewReason,
    required this.reviewedAt,
    required this.updatedAt,
    required this.mlorDeclarations,
    this.latitude,
    this.longitude,
    this.providerPlaceId,
  });

  factory RetailerDeclaration.fromJson(Map<String, dynamic> j) =>
      RetailerDeclaration(
        id: asStr(j['id']),
        code: asStr(j['code']),
        name: asStr(j['name']),
        contactName: asStr(j['contactName']),
        phone: asStr(j['phone']),
        email: asStr(j['email']),
        address: asStr(j['address']),
        latitude: _coordinate(j['latitude'], -90, 90),
        longitude: _coordinate(j['longitude'], -180, 180),
        providerPlaceId: asStrOrNull(j['providerPlaceId']),
        status: DeclarationStatus.fromCode(asStrOrNull(j['status'])),
        retailerType:
            RetailerTypeOption.fromCode(asStrOrNull(j['retailerType'])),
        forecastRevenue: asDouble(j['forecastRevenue']),
        storeSizeSquareMeters: asDouble(j['storeSizeSquareMeters']),
        storeSizeCategory: asStr(j['storeSizeCategory']),
        purchasingCapacity: asDouble(j['purchasingCapacity']),
        purchaseFrequencyPerMonth: asInt(j['purchaseFrequencyPerMonth']),
        requestedCreditTermDays: asInt(j['requestedCreditTermDays']),
        creditTermDays: asInt(j['creditTermDays']),
        potentialClass: asStr(j['potentialClass']),
        assessmentNote: asStr(j['assessmentNote']),
        salesGroupCode: asStr(j['salesGroupCode']),
        reviewReason: asStr(j['reviewReason']),
        reviewedAt: asDate(j['reviewedAt']),
        updatedAt: asDate(j['updatedAt']),
        mlorDeclarations:
            mapList(j['mlorDeclarations'], MlorDeclaration.fromJson),
      );

  final String id;

  /// `KB-xxxx` before approval, 8-digit business code after.
  final String code;
  final String name;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? providerPlaceId;
  final DeclarationStatus status;
  final RetailerTypeOption retailerType;
  final double forecastRevenue;
  final double storeSizeSquareMeters;

  /// S / M / L, computed by the backend from m².
  final String storeSizeCategory;
  final double purchasingCapacity;
  final int purchaseFrequencyPerMonth;
  final int requestedCreditTermDays;

  /// Set by Admin on approval.
  final int creditTermDays;

  /// A / B / C, computed by the backend.
  final String potentialClass;
  final String assessmentNote;
  final String salesGroupCode;
  final String reviewReason;
  final DateTime? reviewedAt;
  final DateTime? updatedAt;
  final List<MlorDeclaration> mlorDeclarations;

  static double? _coordinate(Object? value, double min, double max) {
    if (value == null) { return null; }
    final number = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (number == null || !number.isFinite || number < min || number > max) {
      throw const ApiException(kind: ApiErrorKind.server,
          message: 'Tọa độ khai báo trả về không hợp lệ. Vui lòng tải lại.');
    }
    return number;
  }
}

/// Body of `POST /retailers` (with region/group) and
/// `PUT /retailers/{id}/declaration` (without).
class RetailerDeclarationInput {
  const RetailerDeclarationInput({
    required this.name,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.address,
    required this.retailerType,
    required this.forecastRevenue,
    required this.storeSizeSquareMeters,
    required this.purchasingCapacity,
    required this.purchaseFrequencyPerMonth,
    required this.requestedCreditTermDays,
    required this.assessmentNote,
    required this.mlorDeclarations,
    required this.submitForReview,
    this.latitude,
    this.longitude,
    this.providerPlaceId,
  });

  final String name;
  final String contactName;
  final String phone;
  final String email;
  final String address;
  final RetailerTypeOption retailerType;
  final double forecastRevenue;
  final double storeSizeSquareMeters;
  final double purchasingCapacity;
  final int purchaseFrequencyPerMonth;
  final int requestedCreditTermDays;
  final String assessmentNote;
  final List<MlorDeclaration> mlorDeclarations;
  final bool submitForReview;
  final double? latitude;
  final double? longitude;
  final String? providerPlaceId;

  Map<String, dynamic> toJson({String? regionId, String? salesGroupId}) {
    if ((latitude != null || longitude != null) &&
        !MapPlace.validCoordinates(latitude, longitude)) {
      throw const ApiException(kind: ApiErrorKind.validation,
          message: 'Vui lòng chọn lại vị trí hợp lệ trên bản đồ.');
    }
    return <String, dynamic>{
        if (regionId != null) 'regionId': regionId,
        if (salesGroupId != null) 'salesGroupId': salesGroupId,
        'name': name,
        'contactName': contactName,
        'phone': phone,
        'email': email,
        'address': address.isEmpty ? null : address,
        'retailerType': retailerType.code,
        'forecastRevenue': forecastRevenue,
        'storeSizeSquareMeters': storeSizeSquareMeters,
        'purchasingCapacity': purchasingCapacity,
        'purchaseFrequencyPerMonth': purchaseFrequencyPerMonth,
        'requestedCreditTermDays': requestedCreditTermDays,
        'assessmentNote': assessmentNote.isEmpty ? null : assessmentNote,
        'latitude': latitude,
        'longitude': longitude,
        'providerPlaceId': providerPlaceId,
        'mlorDeclarations': mlorDeclarations.map((e) => e.toJson()).toList(),
        'submitForReview': submitForReview,
      };
  }
}

/// Sales group the signed-in Sales can declare into (`GET /sales-groups/{id}`).
class SalesTerritory {
  const SalesTerritory({
    required this.salesGroupId,
    required this.salesGroupCode,
    required this.salesGroupName,
    required this.regionId,
    required this.regionName,
  });

  factory SalesTerritory.fromJson(Map<String, dynamic> j) => SalesTerritory(
        salesGroupId: asStr(j['id']),
        salesGroupCode: asStr(j['code']),
        salesGroupName: asStr(j['name']),
        regionId: asStr(j['regionId']),
        regionName: asStr(j['regionName']),
      );

  final String salesGroupId;
  final String salesGroupCode;
  final String salesGroupName;
  final String regionId;
  final String regionName;

  String get label => '$salesGroupCode · $regionName';
}

/// Lookup option for the MLOR picker (category or SKU).
class MlorScopeOption {
  const MlorScopeOption({
    required this.id,
    required this.code,
    required this.name,
    this.shelfLifeHours,
  });

  factory MlorScopeOption.category(Map<String, dynamic> j) => MlorScopeOption(
      id: asStr(j['id']), code: asStr(j['code']), name: asStr(j['name']));

  factory MlorScopeOption.product(Map<String, dynamic> j) => MlorScopeOption(
        id: asStr(j['id']),
        code: asStr(j['sku']),
        name: asStr(j['name']),
        shelfLifeHours: asInt(j['shelfLifeHours']),
      );

  final String id;
  final String code;
  final String name;

  /// Products only.
  final int? shelfLifeHours;

  String get label => '$code · $name';
}
