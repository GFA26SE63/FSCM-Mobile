import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/models/retailer_order_eligibility.dart';

final retailersApiProvider =
    Provider<RetailersApi>((ref) => RetailersApi(ref.watch(apiClientProvider)));

/// A GraphQL answer that arrived but is not usable. Unlike a refused query it
/// is never retried through REST.
class _UnusableAnswer extends ApiException {
  const _UnusableAnswer(String message)
      : super(kind: ApiErrorKind.server, message: message);
}

class RetailersApi {
  RetailersApi(this._client) : _graphQl = GraphQlClient(_client);

  final ApiClient _client;
  final GraphQlClient _graphQl;

  // `entities.retailerProfiles(scope: "mine")` runs the same
  // RetailerService.SearchAsync as REST GET /retailers?scope=mine. The service
  // accepts `scope` only for a Sales user and filters on the token's user id
  // (DeclaredByUserId == actor), so another role is refused whatever the app
  // sends. WITHOUT `scope` that query has no role gate and lists every retailer
  // (with MLOR declarations) to any signed-in role: it is never used here.
  static const String _declarationsQuery = '''
    query MyDeclarations(\$page: Int!, \$pageSize: Int!) {
      entities {
        retailerProfiles(scope: "mine", page: \$page, pageSize: \$pageSize) {
          items {
            id code name contactName phone email address latitude longitude
            providerPlaceId status retailerType forecastRevenue
            storeSizeSquareMeters storeSizeCategory purchasingCapacity
            purchaseFrequencyPerMonth creditTermDays potentialClass
            assessmentNote salesGroupCode reviewReason reviewedAt updatedAt
            mlorDeclarations {
              scope productCategoryId productId productSku productName
              categoryCode categoryName minimumLifeRatio minimumLifeHours
            }
          }
          page pageSize totalCount totalPages
        }
      }
    }''';

  // Shared master data, readable by every signed-in role in REST as well.
  // Only the picker fields are selected: never the category default MLOR.
  static const String _categoriesQuery = '''
    query PickerCategories(\$after: String) {
      entities {
        productCategories(
            first: 100, after: \$after,
            where: { isActive: { eq: true } }, order: [{ code: ASC }]) {
          nodes { id code name isActive }
          pageInfo { hasNextPage endCursor }
        }
      }
    }''';

  static const String _productsQuery = '''
    query PickerProducts {
      entities {
        products(first: 100, order: [{ sku: ASC }]) {
          nodes { id sku name shelfLifeHours status }
        }
      }
    }''';

  /// Safety stop for the page loops; reaching it is an error, not a short list.
  static const int _maxPages = 500;

  Future<List<Retailer>> list({
    String? search,
    int page = 1,
    int size = 100,
  }) async {
    final data = await _client.get(
      Endpoints.retailers,
      query: <String, dynamic>{
        'search': search,
        'page': page,
        'pageSize': size.clamp(1, 100),
      },
    );
    return unwrapItems(data).map(Retailer.fromJson).toList();
  }

  /// Backend expects a retailer ID, not the customer code.
  Future<Retailer> get(String retailerId) async {
    final data = await _client.get(Endpoints.retailer(retailerId));
    return Retailer.fromJson(asMap(data));
  }

  /// Sales only. A denied result is a valid response with isEligible=false.
  Future<RetailerOrderEligibility> orderEligibility(
    String retailerId,
  ) async {
    if (retailerId.trim().isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Điểm bán chưa có ID từ máy chủ. Hãy cập nhật dữ liệu.',
      );
    }

    final data = await _client.get(
      Endpoints.retailerOrderEligibility(retailerId),
    );

    try {
      return RetailerOrderEligibility.fromJson(asMap(data));
    } on FormatException catch (error) {
      throw ApiException(
        kind: ApiErrorKind.server,
        message: 'Không đọc được điều kiện đặt hàng từ máy chủ.',
        details: error.message,
      );
    }
  }

  Future<List<RetailerDeclaration>> myDeclarations() async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _declarationRowsGraphQl();
    } on _UnusableAnswer {
      rethrow;
    } on ApiException catch (error) {
      if (!GraphQlClient.canFallBackToRest(error)) rethrow;
      rows = await _declarationRowsRest();
    }
    final result = rows.map(RetailerDeclaration.fromJson).toList();
    result.sort(
      (a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> _declarationRowsGraphQl() async {
    final byId = <String, Map<String, dynamic>>{};
    for (var page = 1; page <= _maxPages; page++) {
      final data = await _graphQl.query(
        _declarationsQuery,
        operationName: 'MyDeclarations',
        variables: <String, dynamic>{'page': page, 'pageSize': 100},
      );
      final result = asMap(asMap(data['entities'])['retailerProfiles']);
      if (result['items'] is! List || result['totalPages'] is! num) {
        throw const _UnusableAnswer(
            'Phản hồi danh sách khai báo không hợp lệ.');
      }
      for (final row in asMapList(result['items'])) {
        byId[asStr(row['id'])] = row;
      }
      if (page >= asInt(result['totalPages'], 1)) return byId.values.toList();
    }
    throw const _UnusableAnswer(
        'Danh sách khai báo quá dài, không thể tải đầy đủ.');
  }

  Future<List<Map<String, dynamic>>> _declarationRowsRest() async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final data = asMap(
        await _client.get(
          Endpoints.retailers,
          query: <String, dynamic>{
            'scope': 'mine',
            'page': page,
            'pageSize': 100,
          },
        ),
      );
      rows.addAll(unwrapItems(data));
      if (page >= asInt(data['totalPages'], 1)) break;
      page++;
    }
    return rows;
  }

  Future<RetailerDeclaration> declare(
    RetailerDeclarationInput input, {
    required String regionId,
    required String salesGroupId,
  }) async {
    final data = await _client.post(
      Endpoints.retailers,
      body: input.toJson(
        regionId: regionId,
        salesGroupId: salesGroupId,
      ),
    );
    return RetailerDeclaration.fromJson(asMap(data));
  }

  Future<RetailerDeclaration> updateDeclaration(
    String retailerId,
    RetailerDeclarationInput input,
  ) async {
    final data = await _client.put(
      Endpoints.retailerDeclaration(retailerId),
      body: input.toJson(),
    );
    return RetailerDeclaration.fromJson(asMap(data));
  }

  Future<RetailerDeclaration> submitForReview(String retailerId) async {
    final data = await _client.post(
      Endpoints.retailerSubmitReview(retailerId),
    );
    return RetailerDeclaration.fromJson(asMap(data));
  }

  Future<SalesTerritory> salesGroup(String salesGroupId) async {
    final data = await _client.get(Endpoints.salesGroup(salesGroupId));
    return SalesTerritory.fromJson(asMap(data));
  }

  Future<List<MlorScopeOption>> mlorCategories() async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _categoryRowsGraphQl();
    } on _UnusableAnswer {
      rethrow;
    } on ApiException catch (error) {
      if (!GraphQlClient.canFallBackToRest(error)) rethrow;
      rows = unwrapItems(await _client.get(Endpoints.categories));
    }
    return rows
        .where((item) => asBool(item['isActive'], true))
        .map(MlorScopeOption.category)
        .toList();
  }

  /// Every active category, in code order, following the connection cursor.
  Future<List<Map<String, dynamic>>> _categoryRowsGraphQl() async {
    final byId = <String, Map<String, dynamic>>{};
    String? after;
    for (var page = 0; page < _maxPages; page++) {
      final data = await _graphQl.query(
        _categoriesQuery,
        operationName: 'PickerCategories',
        variables: <String, dynamic>{'after': after},
      );
      final connection = asMap(asMap(data['entities'])['productCategories']);
      if (connection['nodes'] is! List) {
        throw const _UnusableAnswer('Phản hồi danh mục sản phẩm không hợp lệ.');
      }
      final before = byId.length;
      for (final row in asMapList(connection['nodes'])) {
        byId[asStr(row['id'])] = row;
      }
      final info = asMap(connection['pageInfo']);
      final next = asStrOrNull(info['endCursor']);
      if (info['hasNextPage'] != true ||
          next == null ||
          byId.length == before) {
        return byId.values.toList();
      }
      after = next;
    }
    throw const _UnusableAnswer(
        'Danh mục sản phẩm quá dài, không thể tải đầy đủ.');
  }

  /// First 100 products by SKU (what REST returned for page 1, size 100), the
  /// inactive ones dropped as before. The search box filters on the device.
  Future<List<MlorScopeOption>> mlorProducts({String? search}) async {
    // `search` is not used by the picker; with one, the case-insensitive REST
    // search stays authoritative (GraphQL `contains` is case-sensitive).
    if (search != null && search.trim().isNotEmpty) {
      return _productOptions(unwrapItems(await _client.get(
        Endpoints.products,
        query: <String, dynamic>{'search': search, 'page': 1, 'pageSize': 100},
      )));
    }
    List<Map<String, dynamic>> rows;
    final Object? nodes;
    try {
      final data =
          await _graphQl.query(_productsQuery, operationName: 'PickerProducts');
      nodes = asMap(asMap(data['entities'])['products'])['nodes'];
    } on ApiException catch (error) {
      if (!GraphQlClient.canFallBackToRest(error)) rethrow;
      return _productOptions(unwrapItems(await _client.get(
        Endpoints.products,
        query: <String, dynamic>{'page': 1, 'pageSize': 100},
      )));
    }
    if (nodes is! List) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Phản hồi danh sách sản phẩm không hợp lệ.');
    }
    rows = asMapList(nodes);
    return _productOptions(rows);
  }

  List<MlorScopeOption> _productOptions(List<Map<String, dynamic>> rows) => rows
      .where((item) => asStr(item['status']) != 'Inactive')
      .map(MlorScopeOption.product)
      .toList();
}
