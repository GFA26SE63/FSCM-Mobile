import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/data/local/redemption_attempt_store.dart';
import 'package:fscm_mobile/data/models/redemption_attempt.dart';

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
    FutureProvider.autoDispose<LoyaltyAccount>((ref) async {
  ref.watch(dataVersionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.hasPermission('api:LoyaltyCards.Me')) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Cần đăng nhập điểm bán để xem thẻ tích điểm của mình.');
  }
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final result = await ref.watch(loyaltyRepositoryProvider).account();
  if (disposed || ref.read(currentUserProvider)?.id != user.id) {
    throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Phiên đăng nhập đã thay đổi.');
  }
  final code = user.retailerCode;
  if (code != null && code.isNotEmpty && code != result.retailerCode) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Thẻ tích điểm không thuộc điểm bán của tài khoản này.');
  }
  return result;
});

final giftsProvider = FutureProvider.autoDispose<List<Gift>>((ref) async {
  final card = ref.watch(loyaltyAccountProvider.future);
  final repository = ref.watch(loyaltyRepositoryProvider);
  final account = await card;
  if (account.programId == null) {
    return <Gift>[];
  }
  return repository.gifts(programId: account.programId!);
});

final redemptionAttemptStoreProvider = Provider<RedemptionAttemptStore>(
    (ref) => RedemptionAttemptStore(server: Env.effectiveApiBaseUrl));

final pendingRedemptionProvider =
    FutureProvider.autoDispose<RedemptionAttempt?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }
  return ref.watch(redemptionAttemptStoreProvider).read(user.id);
});

final redemptionsProvider =
    FutureProvider.autoDispose<List<GiftRedemption>>((ref) {
  ref.watch(currentUserProvider);
  ref.watch(dataVersionProvider);
  return ref.watch(loyaltyRepositoryProvider).redemptions();
});

final complaintsProvider = FutureProvider.autoDispose<List<Complaint>>((ref) {
  final user = ref.watch(currentUserProvider);
  // GraphQL `complaintReads` is open to any signed-in role and only a Retailer
  // is limited to own complaints, whereas REST refuses other roles. The list is
  // a Retailer screen, so anyone else is refused here, as REST would.
  if (user?.hasPermission('api:Complaints.List') != true) {
    throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Chỉ điểm bán được xem danh sách khiếu nại này.');
  }
  return ref.watch(loyaltyRepositoryProvider).complaints();
});

final complaintEvidenceProvider = FutureProvider.autoDispose
    .family<List<ComplaintEvidence>, String>((ref, id) {
  return ref.watch(loyaltyRepositoryProvider).complaintEvidence(id);
});
final receivedComplaintLabelsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, orderId) {
  if (orderId.isEmpty) return Future.value(const <String>[]);
  return ref.watch(loyaltyRepositoryProvider).receivedLabels(orderId);
});

final complaintTargetsProvider = FutureProvider.autoDispose
    .family<List<ComplaintTarget>, String>((ref, orderId) {
  ref.watch(currentUserProvider);
  return ref.watch(loyaltyRepositoryProvider).targets(orderId);
});

/// Retailer side: points, gifts, redemptions and complaints.
class LoyaltyRepository {
  LoyaltyRepository(
      {required LoyaltyApi loyalty, required ComplaintsApi complaints})
      : _loyalty = loyalty,
        _complaints = complaints;

  final LoyaltyApi _loyalty;
  final ComplaintsApi _complaints;

  Future<List<ComplaintTarget>> targets(String orderId) =>
      _complaints.targets(orderId);

  Future<LoyaltyAccount> account() => _loyalty.account();

  Future<List<Gift>> gifts({required String programId}) =>
      _loyalty.gifts(programId: programId);

  Future<List<GiftRedemption>> redemptions() => _loyalty.redemptions();

  /// Points are held right away; refunded if the request is rejected.
  Future<GiftRedemption> redeem(RedemptionAttempt attempt) => _loyalty.redeem(
      rewardId: attempt.rewardId,
      quantity: attempt.quantity,
      operationKey: attempt.operationKey);

  Future<List<Complaint>> complaints() => _complaints.list();

  Future<void> addComplaintEvidence(String id, String path,
          {Uint8List? bytes, String? fileName}) =>
      _complaints.addEvidence(id, path, bytes: bytes, fileName: fileName);

  Future<List<ComplaintEvidence>> complaintEvidence(String id) =>
      _complaints.evidence(id);

  Future<void> removeComplaintEvidence(String id, String evidenceId) =>
      _complaints.removeEvidence(id, evidenceId);

  Future<void> cancelComplaint(String id) => _complaints.cancel(id);

  Future<Complaint> complain(NewComplaint request) =>
      _complaints.create(request);

  Future<List<String>> receivedLabels(String orderId) =>
      _complaints.receivedLabels(orderId);
}
