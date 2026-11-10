import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

Future<String> resolveCatalogId(
    ApiClient client, String path, String field, String code) async {
  final data = await client.get(path,
      query: {'search': code, 'page': 1, 'size': 100, 'pageSize': 100});
  final rows = unwrapItems(data)
      .where((row) => asStr(row[field]).toLowerCase() == code.toLowerCase())
      .toList();
  if (rows.length != 1 || asStr(rows.single['id']).isEmpty) {
    throw ApiException(
        kind: ApiErrorKind.validation,
        message:
            'Không tìm thấy mã $code trong danh mục hiện tại. Đồng bộ lại dữ liệu.');
  }
  return asStr(rows.single['id']);
}
