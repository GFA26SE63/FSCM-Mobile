import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/offline_expected_condition.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/sync_snapshot.dart';

class OfflineConditionBuilder {
  OfflineConditionBuilder._();

  static List<OfflineExpectedCondition> capture({
    required SyncSnapshot snapshot,
    required String retailerId,
    required List<CartLine> lines,
    required DateTime at,
  }) {
    final products = {
      for (final row in _rows(snapshot.raw, 'products')) asStr(row['id']): row,
    };

    final categories = {
      for (final row in _rows(snapshot.raw, 'categories'))
        asStr(row['id']): row,
    };

    final rules = _rows(snapshot.raw, 'mlors')
        .where(
          (row) =>
              asStr(row['retailerId']) == retailerId &&
              asBool(row['isActive']) &&
              _effectiveAt(row, at),
        )
        .toList();

    final productIds = lines.map((line) => line.productId).toSet();

    if (productIds.isEmpty || productIds.contains('')) {
      throw _invalid('Sản phẩm thiếu ID máy chủ.');
    }

    final result = <OfflineExpectedCondition>[];

    for (final productId in productIds) {
      final product = products[productId];

      if (product == null) {
        throw _invalid('Snapshot không có sản phẩm $productId.');
      }

      final price = snapshot.priceForProduct(productId, at);
      if (price == null || !price.isFinite || price < 0) {
        throw _invalid(
          'Thiếu giá hiệu lực cho ${asStr(product['sku'])}.',
        );
      }

      Map<String, dynamic>? selected = _latest(
        rules.where(
          (row) => asStr(row['productId']) == productId,
        ),
      );

      if (selected == null) {
        var categoryId = asStr(product['categoryId']);
        final visited = <String>{};

        while (categoryId.isNotEmpty) {
          if (!visited.add(categoryId)) {
            throw _invalid('Cây danh mục có vòng lặp.');
          }

          selected = _latest(
            rules.where(
              (row) => asStr(row['categoryId']) == categoryId,
            ),
          );

          if (selected != null) {
            break;
          }

          final category = categories[categoryId];

          if (category == null) {
            throw _invalid(
              'Snapshot thiếu dữ liệu cây danh mục để xác định MLOR.',
            );
          }

          categoryId = asStr(category['parentCategoryId']);
        }
      }

      if (selected == null) {
        final fallback = asMap(snapshot.raw['defaultMlor']);
        final effectiveFrom = asDate(fallback['effectiveFrom']);

        if (fallback.isEmpty ||
            effectiveFrom == null ||
            at.isBefore(effectiveFrom)) {
          throw _invalid(
            'Snapshot chưa có cấu hình MLOR mặc định hợp lệ.',
          );
        }

        selected = fallback;
      }

      final condition = OfflineExpectedCondition(
        productId: productId,
        expectedBaseUnitPrice: price,
        expectedMlorVersion: asInt(selected['version']),
        expectedMlorRatio: asDouble(
          selected['minimumLifeRatio'],
          double.nan,
        ),
      );

      if (!condition.isValid) {
        throw _invalid(
          'Điều kiện giá/MLOR của ${asStr(product['sku'])} '
          'không hợp lệ.',
        );
      }

      result.add(condition);
    }

    return List<OfflineExpectedCondition>.unmodifiable(result);
  }

  static Map<String, dynamic>? _latest(
    Iterable<Map<String, dynamic>> source,
  ) {
    final items = source.toList()
      ..sort(
        (a, b) => asInt(b['version']).compareTo(asInt(a['version'])),
      );

    return items.isEmpty ? null : items.first;
  }

  static bool _effectiveAt(
    Map<String, dynamic> row,
    DateTime at,
  ) {
    final start = asDate(row['effectiveFrom']);
    final end = asDate(row['effectiveTo']);

    if (start == null || (row['effectiveTo'] != null && end == null)) {
      throw _invalid('Thời gian hiệu lực MLOR không hợp lệ.');
    }

    return !at.isBefore(start) && (end == null || at.isBefore(end));
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is! List || value.any((item) => item is! Map)) {
      throw _invalid('Snapshot thiếu hoặc sai dữ liệu $key.');
    }

    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static ApiException _invalid(String detail) => ApiException(
        kind: ApiErrorKind.validation,
        message: '$detail Hãy cập nhật snapshot trước khi lưu draft.',
      );
}
