import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_registration.dart';

final retailersApiProvider =
    Provider<RetailersApi>((ref) => RetailersApi(ref.watch(apiClientProvider)));

class RetailersApi {
  RetailersApi(this._client);

  final ApiClient _client;

  Future<List<Retailer>> list(
      {String? search, int page = 1, int size = 100}) async {
    final data = await _client.get(
      Endpoints.retailers,
      query: <String, dynamic>{'search': search, 'page': page, 'size': size},
    );
    return unwrapItems(data).map(Retailer.fromJson).toList();
  }

  Future<Retailer> get(String code) async {
    final data = await _client.get(Endpoints.retailer(code));
    return Retailer.fromJson(asMap(data));
  }

  /// Declarations (KB-0000) created by the signed-in Sales.
  Future<List<RetailerRegistration>> registrations() async {
    final data = await _client.get(Endpoints.retailerRegistrations);
    return unwrapItems(data).map(RetailerRegistration.fromJson).toList();
  }

  Future<RetailerRegistration> declare(NewRegistration request) async {
    final data = await _client.post(Endpoints.retailerRegistrations,
        body: request.toJson());
    return RetailerRegistration.fromJson(asMap(data));
  }
}
