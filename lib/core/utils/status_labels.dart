import 'package:flutter/foundation.dart';

/// Vietnamese display text for backend status strings that the app shows as
/// they arrive. Only the text shown to the user is mapped; the raw values stay
/// in the models and API payloads.
const String unknownStatusLabel = 'Chưa rõ trạng thái';

/// Order allocation state ("Phân bổ"). Backend `OrderService.AllocationState`,
/// derived from the ORDER status: Allocating | Allocated | Failed | NotApplicable.
String allocationStateLabel(String? value) => switch (value) {
      'Allocating' => 'Đang phân bổ hàng',
      'Allocated' => 'Đã phân bổ hàng',
      'Failed' => 'Phân bổ không thành công',
      'NotApplicable' => 'Không áp dụng',
      _ => _unknown('allocationState', value),
    };

/// Result of the allocation RUN that served the order ("Kết quả"). The Backend
/// sends the run's status in this field (`OrderStore.LoadAllocationContextAsync`
/// → `AllocationRunStatuses`): Processing | Succeeded | OutOfStock | Conflict |
/// TechnicalFailed. It is not the order-level state above, and it is absent
/// (null) while no run exists yet.
String allocationResultLabel(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Chưa có kết quả phân bổ';
  return switch (v) {
    'Processing' => 'Đang xử lý phân bổ',
    'Succeeded' => 'Phân bổ thành công',
    'OutOfStock' => 'Không đủ hàng để phân bổ',
    'Conflict' => 'Xung đột khi phân bổ',
    'TechnicalFailed' => 'Phân bổ gặp lỗi hệ thống',
    _ => _unknown('allocationResult', v),
  };
}

/// Unknown backend value: safe Vietnamese text for the user, the raw value only
/// in debug logs (status codes carry no personal data).
String _unknown(String field, String? raw) {
  if (kDebugMode) debugPrint('[STATUS-UNMAPPED] $field="$raw"');
  return unknownStatusLabel;
}
