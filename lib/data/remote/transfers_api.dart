import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/transfer.dart';

final transfersApiProvider =
    Provider<TransfersApi>((ref) => TransfersApi(ref.watch(apiClientProvider)));

class TransfersApi {
  TransfersApi(this._client);

  final ApiClient _client;

  /// Transfers going to the Warehouse Keeper's warehouse.
  Future<List<Transfer>> list({String? status, String? kind}) async {
    final data = await _client.get(
      Endpoints.transfers,
      query: <String, dynamic>{'status': status, 'kind': kind},
    );
    return unwrapItems(data).map(Transfer.fromJson).toList();
  }

  Future<Transfer> get(String code) async {
    final data = await _client.get(Endpoints.transfer(code));
    return Transfer.fromJson(asMap(data));
  }

  /// `POST /transfers/{code}/receive` with the scanned labels.
  Future<Transfer> receive(String code,
      {required List<String> labelCodes}) async {
    final data = await _client.post(
      Endpoints.transferReceive(code),
      body: <String, dynamic>{'labelCodes': labelCodes},
    );
    return Transfer.fromJson(asMap(data));
  }
}
