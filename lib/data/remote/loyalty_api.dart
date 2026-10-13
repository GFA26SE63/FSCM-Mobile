import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';

final loyaltyApiProvider =
    Provider<LoyaltyApi>((ref) => LoyaltyApi(ref.watch(apiClientProvider)));

/// `/loyalty/*`, `/gifts`, `/gift-redemptions`.
class LoyaltyApi {
  LoyaltyApi(this._client);

  final ApiClient _client;

  Future<LoyaltyAccount> account(String retailerCode) async {
    final data = await _client.get(Endpoints.loyaltyRetailer(retailerCode));
    return LoyaltyAccount.fromJson(asMap(data));
  }

  Future<List<LoyaltyProgram>> programs() async {
    final data = await _client.get(Endpoints.loyaltyPrograms);
    return unwrapItems(data).map(LoyaltyProgram.fromJson).toList();
  }

  Future<List<Gift>> gifts() async {
    final data = await _client.get(Endpoints.gifts);
    return unwrapItems(data).map(Gift.fromJson).toList();
  }

  Future<List<GiftRedemption>> redemptions() async {
    final data = await _client.get(Endpoints.giftRedemptions);
    return unwrapItems(data).map(GiftRedemption.fromJson).toList();
  }

  /// Points are held immediately and refunded if the request is rejected.
  Future<GiftRedemption> redeem(String giftCode) async {
    final data = await _client.post(
      Endpoints.giftRedemptions,
      body: <String, dynamic>{'giftCode': giftCode},
    );
    return GiftRedemption.fromJson(asMap(data));
  }
}
