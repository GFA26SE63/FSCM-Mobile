import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

final complaintsApiProvider = Provider<ComplaintsApi>(
    (ref) => ComplaintsApi(ref.watch(apiClientProvider)));

class ComplaintsApi {
  ComplaintsApi(this._client);

  final ApiClient _client;

  Future<List<Complaint>> list() async {
    final data = await _client.get(Endpoints.complaints);
    return unwrapItems(data).map(Complaint.fromJson).toList();
  }

  Future<Complaint> create(NewComplaint request) async {
    final data =
        await _client.post(Endpoints.complaints, body: request.toJson());
    return Complaint.fromJson(asMap(data));
  }
}
