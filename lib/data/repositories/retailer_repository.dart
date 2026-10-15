import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/retailer_registration.dart';
import 'package:fscm_mobile/data/remote/retailers_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final retailerRepositoryProvider = Provider<RetailerRepository>(
    (ref) => RetailerRepository(ref.watch(retailersApiProvider)));

/// Declarations (KB-0000) of the signed-in Sales.
final registrationsProvider =
    FutureProvider.autoDispose<List<RetailerRegistration>>((ref) {
  ref.watch(dataVersionProvider);
  ref.watch(currentUserProvider);
  return ref.watch(retailerRepositoryProvider).registrations();
});

class RetailerRepository {
  RetailerRepository(this._api);

  final RetailersApi _api;

  Future<List<RetailerRegistration>> registrations() => _api.registrations();

  Future<RetailerRegistration> declare(NewRegistration request) =>
      _api.declare(request);
}
