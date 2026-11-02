import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';

final retailersApiProvider =
    Provider<RetailersApi>((ref) => RetailersApi(ref.watch(apiClientProvider)));

class RetailersApi {
  RetailersApi(this._client);

  final ApiClient _client;

  Future<List<Retailer>> list(
      {String? search, int page = 1, int size = 100}) async {
    final data = await _client.get(
      Endpoints.retailers,
      // Backend `GET /retailers` pages with `pageSize` (1..100).
      query: <String, dynamic>{
        'search': search,
        'page': page,
        'pageSize': size.clamp(1, 100),
      },
    );
    return unwrapItems(data).map(Retailer.fromJson).toList();
  }

  Future<Retailer> get(String code) async {
    final data = await _client.get(Endpoints.retailer(code));
    return Retailer.fromJson(asMap(data));
  }

  /// Declarations created by the signed-in Sales (`GET /retailers?scope=mine`).
  Future<List<RetailerDeclaration>> myDeclarations() async {
    final result = <RetailerDeclaration>[];
    var page = 1;
    while (true) {
      final data = asMap(await _client.get(
        Endpoints.retailers,
        query: <String, dynamic>{
          'scope': 'mine',
          'page': page,
          'pageSize': 100
        },
      ));
      result.addAll(unwrapItems(data).map(RetailerDeclaration.fromJson));
      if (page >= asInt(data['totalPages'], 1)) break;
      page++;
    }
    // Newest first is more useful on the phone than code order.
    result.sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return result;
  }

  Future<RetailerDeclaration> declare(RetailerDeclarationInput input,
      {required String regionId, required String salesGroupId}) async {
    final data = await _client.post(Endpoints.retailers,
        body: input.toJson(regionId: regionId, salesGroupId: salesGroupId));
    return RetailerDeclaration.fromJson(asMap(data));
  }

  Future<RetailerDeclaration> updateDeclaration(
      String retailerId, RetailerDeclarationInput input) async {
    final data = await _client.put(Endpoints.retailerDeclaration(retailerId),
        body: input.toJson());
    return RetailerDeclaration.fromJson(asMap(data));
  }

  Future<RetailerDeclaration> submitForReview(String retailerId) async {
    final data = await _client.post(Endpoints.retailerSubmitReview(retailerId));
    return RetailerDeclaration.fromJson(asMap(data));
  }

  /// Sales group + region pair used for `regionId` / `salesGroupId`.
  Future<SalesTerritory> salesGroup(String salesGroupId) async {
    final data = await _client.get(Endpoints.salesGroup(salesGroupId));
    return SalesTerritory.fromJson(asMap(data));
  }

  /// Active categories for an MLOR Category scope.
  Future<List<MlorScopeOption>> mlorCategories() async {
    final data = await _client.get(Endpoints.categories);
    return unwrapItems(data)
        .where((e) => asBool(e['isActive'], true))
        .map(MlorScopeOption.category)
        .toList();
  }

  /// Non-inactive SKUs for an MLOR SKU scope.
  Future<List<MlorScopeOption>> mlorProducts({String? search}) async {
    final data = await _client.get(
      Endpoints.products,
      query: <String, dynamic>{'search': search, 'page': 1, 'pageSize': 100},
    );
    return unwrapItems(data)
        .where((e) => asStr(e['status']) != 'Inactive')
        .map(MlorScopeOption.product)
        .toList();
  }
}
