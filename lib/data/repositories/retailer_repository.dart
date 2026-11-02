import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/remote/auth_api.dart';
import 'package:fscm_mobile/data/remote/retailers_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final retailerRepositoryProvider = Provider<RetailerRepository>((ref) =>
    RetailerRepository(
        ref.watch(retailersApiProvider), ref.watch(authApiProvider)));

/// Declarations created by the signed-in Sales.
final declarationsProvider =
    FutureProvider.autoDispose<List<RetailerDeclaration>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(retailerRepositoryProvider).myDeclarations();
});

/// Sales groups (with their region) the signed-in Sales can declare into.
final salesTerritoriesProvider =
    FutureProvider.autoDispose<List<SalesTerritory>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(retailerRepositoryProvider).territories(user);
});

final mlorCategoriesProvider =
    FutureProvider.autoDispose<List<MlorScopeOption>>(
        (ref) => ref.watch(retailerRepositoryProvider).mlorCategories());

final mlorProductsProvider = FutureProvider.autoDispose<List<MlorScopeOption>>(
    (ref) => ref.watch(retailerRepositoryProvider).mlorProducts());

class RetailerRepository {
  RetailerRepository(this._api, this._authApi);

  final RetailersApi _api;
  final AuthApi _authApi;

  Future<List<RetailerDeclaration>> myDeclarations() => _api.myDeclarations();

  /// Uses the scope stored with the session; older sessions saved before the
  /// scope was persisted fall back to `GET /auth/me`.
  Future<List<SalesTerritory>> territories(AppUser? user) async {
    var groupIds = user?.salesGroupIds ?? const <String>[];
    if (groupIds.isEmpty) groupIds = (await _authApi.me()).salesGroupIds;
    final territories = <SalesTerritory>[];
    for (final id in groupIds) {
      territories.add(await _api.salesGroup(id));
    }
    return territories;
  }

  Future<RetailerDeclaration> declare(
          RetailerDeclarationInput input, SalesTerritory territory) =>
      _api.declare(input,
          regionId: territory.regionId, salesGroupId: territory.salesGroupId);

  Future<RetailerDeclaration> update(
          String retailerId, RetailerDeclarationInput input) =>
      _api.updateDeclaration(retailerId, input);

  Future<RetailerDeclaration> submitForReview(String retailerId) =>
      _api.submitForReview(retailerId);

  Future<List<MlorScopeOption>> mlorCategories() => _api.mlorCategories();

  Future<List<MlorScopeOption>> mlorProducts() => _api.mlorProducts();
}
