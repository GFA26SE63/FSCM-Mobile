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
    final data = await _client.get(Endpoints.loyaltyCardMe);
    if (data is! Map<String, dynamic>) {
      invalidLoyaltyResponse();
    }
    final card = LoyaltyAccount.fromJson(data);
    if (card.programId == null) {
      return card;
    }
    // Read the exact program on the card, including an inactive one. The
    // active-only list can omit it and must not turn its rate into zero.
    final rawProgram = await _client.get(
        '${Endpoints.loyaltyPrograms}/${Uri.encodeComponent(card.programId!)}');
    if (rawProgram is! Map<String, dynamic>) {
      invalidLoyaltyResponse();
    }
    final program = LoyaltyProgram.fromJson(rawProgram);
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
