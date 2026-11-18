import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<List<Gift>> gifts({required String programId}) async {
    final data = await _client.get(Endpoints.loyaltyRewards,
        query: {'programId': programId});
    final rows = _rows(data).map(Gift.fromJson).toList();
    if (rows.any((gift) => gift.programId != programId || !gift.isActive)) {
      invalidLoyaltyResponse();
    }
    return rows;
  }

  Future<List<GiftRedemption>> redemptions() async {
    final data = await _client.get(Endpoints.loyaltyRedemptions);
    return _rows(data).map(GiftRedemption.fromJson).toList();
  }

  /// Points are held immediately and refunded if the request is rejected.
  Future<GiftRedemption> redeem({required String rewardId,
      required int quantity, required String operationKey}) async {
    if (quantity <= 0 || quantity > 2147483647 || operationKey.trim().isEmpty) {
      throw ArgumentError('Invalid redemption request');
    }
    final data = await _client.post(
      Endpoints.loyaltyRedemptions,
      body: <String, dynamic>{'rewardId': rewardId, 'quantity': quantity},
      headers: <String, String>{'Idempotency-Key': operationKey},
    );
    if (data is! Map<String, dynamic>) {
      invalidLoyaltyResponse();
    }
    final result = GiftRedemption.fromJson(data);
    if (result.clientRequestId != operationKey) {
      invalidLoyaltyResponse();
    }
    return result;
  }

  List<Map<String, dynamic>> _rows(Object? data) {
    if (data is! List<dynamic>) {
      invalidLoyaltyResponse();
    }
    return data.map((row) {
      if (row is! Map<String, dynamic>) {
        invalidLoyaltyResponse();
      }
      return row;
    }).toList();
  }
}
