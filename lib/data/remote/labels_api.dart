import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/label_info.dart';

final labelsApiProvider =
    Provider<LabelsApi>((ref) => LabelsApi(ref.watch(apiClientProvider)));

class LabelsApi {
  LabelsApi(this._client);

  final ApiClient _client;

  Future<LabelInfo> get(String code) async {
    final data = await _client.get(Endpoints.label(code));
    return LabelInfo.fromJson(asMap(data));
  }
}
