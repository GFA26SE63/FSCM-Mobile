import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/shipment.dart';

final shipmentsApiProvider =
    Provider<ShipmentsApi>((ref) => ShipmentsApi(ref.watch(apiClientProvider)));

/// F93/F96: whether an order may leave, and the confirmation that it did.
class ShipmentsApi {
  ShipmentsApi(this._client);

  final ApiClient _client;

  Future<List<Shipment>> list({String? orderId, String? status}) async {
    final data = await _client.get(
      Endpoints.shipments,
      query: <String, dynamic>{'orderId': orderId, 'status': status},
    );
    return unwrapItems(data).map(Shipment.fromJson).toList();
  }

  /// F93. The verdict is the server's and it is taken for the whole order.
  Future<OrderShipmentReadiness> readiness(String orderId) async {
    final data = await _client.get(Endpoints.orderShipmentReadiness(orderId));
    return OrderShipmentReadiness.fromJson(asMap(data));
  }

  /// F96. Confirms that this warehouse's part physically left.
  ///
  /// This is where OnHand and Reserved fall, together, and nowhere else. It is
  /// not the pick scan and not the retailer's receipt. Sending it again returns
  /// the part unchanged instead of deducting a second time - a duplicated
  /// deduction stays invisible until somebody counts the shelf.
  Future<Shipment> confirmIssue(
    String shipmentId, {
    required int expectedVersion,
  }) async {
    final data = await _client.post(
      Endpoints.shipmentIssue(shipmentId),
      body: <String, dynamic>{'expectedVersion': expectedVersion},
    );
    return Shipment.fromJson(asMap(data));
  }
}
