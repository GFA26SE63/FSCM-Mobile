import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/remote/complaints_api.dart';
import 'package:fscm_mobile/data/remote/loyalty_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  return LoyaltyRepository(
    loyalty: ref.watch(loyaltyApiProvider),
    complaints: ref.watch(complaintsApiProvider),
  );
});

final loyaltyAccountProvider =
    FutureProvider.autoDispose<LoyaltyAccount>((ref) {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  return ref.watch(loyaltyRepositoryProvider).account(user?.retailerCode ?? '');
});

final giftsProvider = FutureProvider.autoDispose<List<Gift>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(loyaltyRepositoryProvider).gifts();
});

final redemptionsProvider =
    FutureProvider.autoDispose<List<GiftRedemption>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(loyaltyRepositoryProvider).redemptions();
});

final complaintsProvider = FutureProvider.autoDispose<List<Complaint>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(loyaltyRepositoryProvider).complaints();
});

/// Retailer side: points, gifts, redemptions and complaints.
class LoyaltyRepository {
  LoyaltyRepository(
      {required LoyaltyApi loyalty, required ComplaintsApi complaints})
      : _loyalty = loyalty,
        _complaints = complaints;

  final LoyaltyApi _loyalty;
  final ComplaintsApi _complaints;

  Future<LoyaltyAccount> account(String retailerCode) =>
      _loyalty.account(retailerCode);

  Future<List<Gift>> gifts() => _loyalty.gifts();

  Future<List<GiftRedemption>> redemptions() => _loyalty.redemptions();

  /// Points are held right away; refunded if the request is rejected.
  Future<GiftRedemption> redeem(String giftCode, {int quantity = 1}) =>
      _loyalty.redeem(giftCode, quantity: quantity);

  Future<List<Complaint>> complaints() => _complaints.list();

  Future<Complaint> complain(NewComplaint request) =>
      _complaints.create(request);
}
