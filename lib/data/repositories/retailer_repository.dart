import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/session.dart';
import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/retailer_declaration.dart';
import 'package:fscm_mobile/data/models/retailer_order_eligibility.dart';
import 'package:fscm_mobile/data/remote/auth_api.dart';
import 'package:fscm_mobile/data/remote/retailers_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final retailerRepositoryProvider = Provider<RetailerRepository>(
  (ref) => RetailerRepository(
    ref.watch(retailersApiProvider),
    ref.watch(authApiProvider),
  ),
);

final declarationsProvider =
    FutureProvider.autoDispose<List<RetailerDeclaration>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(retailerRepositoryProvider).myDeclarations();
});

final salesTerritoriesProvider =
    FutureProvider.autoDispose<List<SalesTerritory>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(retailerRepositoryProvider).territories(user);
});

final mlorCategoriesProvider =
    FutureProvider.autoDispose<List<MlorScopeOption>>(
  (ref) => ref.watch(retailerRepositoryProvider).mlorCategories(),
);

final mlorProductsProvider = FutureProvider.autoDispose<List<MlorScopeOption>>(
  (ref) => ref.watch(retailerRepositoryProvider).mlorProducts(),
);

final retailerOrderEligibilityProvider = FutureProvider.autoDispose
    .family<RetailerOrderEligibility, String>((ref, retailerId) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null || user.role != UserRole.sales) {
    throw const ApiException(
      kind: ApiErrorKind.forbidden,
      message: 'Chức năng kiểm tra này dành cho Sales.',
    );
  }

  return ref.watch(retailerRepositoryProvider).orderEligibility(
        retailerId,
        salesUserId: user.id,
      );
});

class RetailerRepository {
  RetailerRepository(this._api, this._authApi);

  final RetailersApi _api;
  final AuthApi _authApi;

  Future<RetailerOrderEligibility> orderEligibility(
    String retailerId, {
    required String salesUserId,
  }) async {
    final result = await _api.orderEligibility(retailerId);

    if (result.retailerId != retailerId || result.salesUserId != salesUserId) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Kết quả kiểm tra không khớp phiên đăng nhập hoặc điểm bán.',
      );
    }

    return result;
  }

  Future<List<RetailerDeclaration>> myDeclarations() => _api.myDeclarations();

  Future<List<SalesTerritory>> territories(AppUser? user) async {
    var groupIds = user?.salesGroupIds ?? const <String>[];
    if (groupIds.isEmpty) {
      groupIds = (await _authApi.me()).salesGroupIds;
    }

    final territories = <SalesTerritory>[];
    for (final id in groupIds) {
      territories.add(await _api.salesGroup(id));
    }
    return territories;
  }

  Future<RetailerDeclaration> declare(
    RetailerDeclarationInput input,
    SalesTerritory territory,
  ) =>
      _api.declare(
        input,
        regionId: territory.regionId,
        salesGroupId: territory.salesGroupId,
      );

  Future<RetailerDeclaration> update(
    String retailerId,
    RetailerDeclarationInput input,
  ) =>
      _api.updateDeclaration(retailerId, input);

  Future<RetailerDeclaration> submitForReview(String retailerId) =>
      _api.submitForReview(retailerId);

  Future<List<MlorScopeOption>> mlorCategories() => _api.mlorCategories();

  Future<List<MlorScopeOption>> mlorProducts() => _api.mlorProducts();
}
