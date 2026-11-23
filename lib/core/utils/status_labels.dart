/// Vietnamese display text for backend status strings that the app shows as
/// they arrive. Values are the Backend's (`OrderService.AllocationState`,
/// `AllocationRunOrderStatuses`); only the text shown to the user is mapped.
const String unknownStatusLabel = 'Chưa rõ trạng thái';

/// Order allocation state ("Phân bổ").
String allocationStateLabel(String? value) => switch (value) {
      'Allocating' => 'Đang phân bổ hàng',
      'Allocated' => 'Đã phân bổ hàng',
      'Failed' => 'Phân bổ không thành công',
      'NotApplicable' => 'Không áp dụng',
      _ => unknownStatusLabel,
    };

/// Result of the allocation run for the order ("Kết quả").
String allocationResultLabel(String? value) => switch (value) {
      'Pending' => 'Chờ kết quả phân bổ',
      'Fulfilled' => 'Đủ hàng',
      'Short' => 'Thiếu hàng',
      'Allocated' => 'Đã phân bổ',
      _ => unknownStatusLabel,
    };
