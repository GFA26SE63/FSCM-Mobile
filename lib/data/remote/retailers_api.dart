import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/models/retailer_order_eligibility.dart';

final retailersApiProvider =
    Provider<RetailersApi>((ref) => RetailersApi(ref.watch(apiClientProvider)));

class RetailersApi {
  RetailersApi(this._client);

  final ApiClient _client;

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
    final result = <RetailerDeclaration>[];
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

      result.addAll(unwrapItems(data).map(RetailerDeclaration.fromJson));

      if (page >= asInt(data['totalPages'], 1)) break;
      page++;
    }

    result.sort(
      (a, b) =>
          (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)),
    );
    return result;
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
    final data = await _client.get(Endpoints.categories);

    return unwrapItems(data)
        .where((item) => asBool(item['isActive'], true))
        .map(MlorScopeOption.category)
        .toList();
  }

  Future<List<MlorScopeOption>> mlorProducts({String? search}) async {
    final data = await _client.get(
      Endpoints.products,
      query: <String, dynamic>{
        'search': search,
        'page': 1,
        'pageSize': 100,
      },
    );

    return unwrapItems(data)
        .where((item) => asStr(item['status']) != 'Inactive')
        .map(MlorScopeOption.product)
        .toList();
  }
}
