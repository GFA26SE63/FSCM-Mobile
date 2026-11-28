import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';

final loyaltyApiProvider =
    Provider<LoyaltyApi>((ref) => LoyaltyApi(ref.watch(apiClientProvider)));

/// Loyalty card, reward catalogue and redemption workflow.
class LoyaltyApi {
  LoyaltyApi(this._client) : _graphQl = GraphQlClient(_client);

  final ApiClient _client;
  final GraphQlClient _graphQl;

  Future<LoyaltyAccount> account() async {
    final data = await _client.get(Endpoints.loyaltyCardMe);
    if (data is! Map<String, dynamic>) {
      invalidLoyaltyResponse();
    }
    final card = LoyaltyAccount.fromJson(data);
    // New cards contain the complete, server-scoped program catalogue.
    if (card.eligiblePrograms != null) return card;
    if (card.programId == null) {
      return card;
    }
    // Read the exact program on the card, including an inactive one. The
    // active-only list can omit it and must not turn its rate into zero.
    final rawProgram = await _programById(card.programId!);
    final program = LoyaltyProgram.fromJson(rawProgram);
    return LoyaltyAccount.fromJson(data, program: program);
  }

  // The card itself stays REST: pending / expired points, the ledger and the
  // program that applies come from LoyaltyCardService and have no GraphQL
  // query. A program is shared master data (any signed-in role, in REST as
  // well) and `loyaltyPrograms` has every field the app reads; it lacks only
  // the retailer id list REST adds, which the app never uses.
  static const String _programQuery = '''
    query LoyaltyProgram(\$id: UUID!) {
      entities {
        loyaltyPrograms(first: 1, where: { id: { eq: \$id } }) {
          nodes {
            id code name spendAmountPerPoint isActive startAt endAt
            pointsExpireAt
          }
        }
      }
    }''';

  Future<Map<String, dynamic>> _programById(String programId) async {
    Object? nodes;
    try {
      final data = await _graphQl.query(_programQuery,
          operationName: 'LoyaltyProgram',
          variables: <String, dynamic>{'id': programId});
      nodes = asMap(asMap(data['entities'])['loyaltyPrograms'])['nodes'];
    } on ApiException catch (error) {
      if (!GraphQlClient.canFallBackToRest(error)) rethrow;
      return _programByIdRest(programId);
    }
    // A malformed answer is an error; an empty one is not trusted either, so
    // REST (which also reports "not found" precisely) decides.
    if (nodes is! List) invalidLoyaltyResponse();
    if (nodes.isEmpty) return _programByIdRest(programId);
    final row = nodes.first;
    if (row is! Map<String, dynamic>) invalidLoyaltyResponse();
    return row;
  }

  Future<Map<String, dynamic>> _programByIdRest(String programId) async {
    final raw = await _client
        .get('${Endpoints.loyaltyPrograms}/${Uri.encodeComponent(programId)}');
    if (raw is! Map<String, dynamic>) invalidLoyaltyResponse();
    return raw;
  }

  Future<List<LoyaltyProgram>> programs() async {
    final data = await _client.get(Endpoints.loyaltyPrograms);
    return unwrapItems(data).map(LoyaltyProgram.fromJson).toList();
  }

  Future<List<Gift>> gifts({required String programId}) async {
    final data = await _client
        .get(Endpoints.loyaltyRewards, query: {'programId': programId});
    final rows = _rows(data).map(Gift.fromJson).toList();
    if (rows.any((gift) => gift.programId != programId || !gift.isActive)) {
      invalidLoyaltyResponse();
    }
    return rows;
  }

  // `entities.redemptionReads` serves the Retailer through
  // RedemptionService.ListAsync(userId), the same call as REST GET
  // /loyalty/redemptions (Admin and Operator use the staff list in both).
  // No filter, sort or paging arguments exist, as in REST. Points and the
  // redemption itself stay on the Backend; the write is REST.
  static const String _redemptionsQuery = '''
    query Redemptions {
      entities {
        redemptionReads {
          id rewardCode rewardName redeemedPoints status createdAt quantity
          quantityIsEstimated clientRequestId
        }
      }
    }''';

  Future<List<GiftRedemption>> redemptions() async {
    Object? rows;
    try {
      final data =
          await _graphQl.query(_redemptionsQuery, operationName: 'Redemptions');
      rows = asMap(data['entities'])['redemptionReads'];
    } on ApiException catch (error) {
      if (!GraphQlClient.canFallBackToRest(error)) rethrow;
      rows = await _client.get(Endpoints.loyaltyRedemptions);
    }
    return _rows(rows).map(GiftRedemption.fromJson).toList();
  }

  /// Points are held immediately and refunded if the request is rejected.
  Future<GiftRedemption> redeem(
      {required String rewardId,
      required int quantity,
      required String operationKey}) async {
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
