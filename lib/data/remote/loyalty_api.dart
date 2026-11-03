import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';

final loyaltyApiProvider =
    Provider<LoyaltyApi>((ref) => LoyaltyApi(ref.watch(apiClientProvider)));

/// Loyalty card, reward catalogue and redemption workflow.
class LoyaltyApi {
  LoyaltyApi(this._client);

  final ApiClient _client;

  Future<LoyaltyAccount> account() async {
    final data = asMap(await _client.get(Endpoints.loyaltyCardMe));
    final programs = await this.programs();
    final programId = asStr(data['programId']);
    final program = programs.where((item) => item.id == programId).firstOrNull;
    return LoyaltyAccount.fromJson(data, program: program);
  }

  Future<List<LoyaltyProgram>> programs() async {
    final data = await _client.get(Endpoints.loyaltyPrograms);
    return unwrapItems(data).map(LoyaltyProgram.fromJson).toList();
  }

  Future<List<Gift>> gifts() async {
    final data = await _client.get(Endpoints.loyaltyRewards);
    return unwrapItems(data).map(Gift.fromJson).toList();
  }

  Future<List<GiftRedemption>> redemptions() async {
    final data = await _client.get(Endpoints.loyaltyRedemptions);
    return unwrapItems(data).map(GiftRedemption.fromJson).toList();
  }

  /// Points are held immediately and refunded if the request is rejected.
  Future<GiftRedemption> redeem(Gift gift) async {
    final data = await _client.post(
      Endpoints.loyaltyRedemptions,
      body: <String, dynamic>{'rewardId': gift.id, 'quantity': 1},
      headers: <String, String>{'Idempotency-Key': const Uuid().v4()},
    );
    return GiftRedemption.fromJson(asMap(data));
  }
}
