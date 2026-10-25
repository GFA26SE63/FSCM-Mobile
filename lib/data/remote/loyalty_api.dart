import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';

final loyaltyApiProvider =
    Provider<LoyaltyApi>((ref) => LoyaltyApi(ref.watch(apiClientProvider)));

  /// `/loyalty/*`.
class LoyaltyApi {
  LoyaltyApi(this._client);

  final ApiClient _client;

  Future<LoyaltyAccount> account(String _retailerCode) async {
    final data = await _client.get(Endpoints.loyaltyCardMe);
    return LoyaltyAccount.fromJson(asMap(data));
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
  Future<GiftRedemption> redeem(String giftCode, {int quantity = 1}) async {
    final data = await _client.post(
      Endpoints.loyaltyRedemptions,
      headers: <String, String>{'Idempotency-Key': _operationKey()},
      body: <String, dynamic>{'rewardId': giftCode, 'quantity': quantity},
    );
    return GiftRedemption.fromJson(asMap(data));
  }

  String _operationKey() => 'mobile-${DateTime.now().microsecondsSinceEpoch}';
}
