import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/label_detail.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

final labelsApiProvider = Provider<LabelsApi>((ref) {
  final user = ref.watch(currentUserProvider);

  final canLookup = user != null &&
      <UserRole>{
        UserRole.admin,
        UserRole.operator,
        UserRole.warehouseKeeper,
      }.contains(user.role);

  return LabelsApi(
    ref.watch(apiClientProvider),
    canLookup: canLookup,
  );
});

class LabelsApi {
  LabelsApi(
    this._client, {
    required this.canLookup,
  });

  final ApiClient _client;
  final bool canLookup;

  Future<LabelInfo> get(String code) async {
    return (await getDetail(code)).label;
  }

  Future<LabelDetail> getDetail(String rawCode) async {
    if (!canLookup) {
      throw const ApiException(
        kind: ApiErrorKind.forbidden,
        message: 'Tài khoản này không có quyền tra cứu tem kho.',
      );
    }

    final code = rawCode.trim().toUpperCase();

    if (!IdFormat.isLabel(code)) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Mã tem không hợp lệ. Ví dụ: TEM-001010.',
      );
    }

    final data = await _client.get(
      Endpoints.label(Uri.encodeComponent(code)),
    );

    try {
      return LabelDetail.fromJson(asMap(data));
    } on FormatException catch (error) {
      throw ApiException(
        kind: ApiErrorKind.server,
        message: 'Dữ liệu tra cứu tem không hợp lệ.',
        details: error.message,
      );
    }
  }
}
