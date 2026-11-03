import 'package:fscm_mobile/core/utils/status_tone.dart';

/// Status vocabulary from SPEC section 9: `code` is the API value,
/// `label` the Vietnamese UI text.

enum OrderStatus {
  allocating('Allocating', 'Đang phân bổ', StatusTone.info),
  quoted('Quoted', 'Chờ xác nhận báo giá', StatusTone.primary),
  allocationFailed('AllocationFailed', 'Phân bổ lỗi', StatusTone.danger),
  outOfStock('OutOfStock', 'Thiếu hàng', StatusTone.danger),
  allocationConflict('AllocationConflict', 'Xung đột tồn', StatusTone.warning),
  paymentPending('PaymentPending', 'Chờ thanh toán', StatusTone.warning),
  convertedToPo('ConvertedToPo', 'Đã tạo PO', StatusTone.primary),
  picking('Picking', 'Đang soạn hàng', StatusTone.purple),
  issued('Issued', 'Đã xuất kho', StatusTone.primary),
  delivering('Delivering', 'Đang giao', StatusTone.purple),
  delivered('Delivered', 'Đã giao', StatusTone.success),
  completed('Completed', 'Hoàn tất', StatusTone.success),
  quoteRejected('QuoteRejected', 'Báo giá bị từ chối', StatusTone.danger),
  quoteExpired('QuoteExpired', 'Báo giá hết hạn', StatusTone.neutral),
  withdrawn('Withdrawn', 'Đã hủy', StatusTone.neutral);

  const OrderStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  /// Not yet delivered / closed (retailer "đang xử lý" tab).
  bool get isActive =>
      this == allocating ||
      this == quoted ||
      this == paymentPending ||
      this == convertedToPo ||
      this == picking ||
      this == issued ||
      this == delivering;

  /// Retailer may still scan the QR to confirm receipt.
  bool get canConfirmReceipt => this == delivering;

  bool get isRejectedOrCancelled =>
      this == quoteRejected || this == quoteExpired || this == withdrawn ||
      this == allocationFailed || this == outOfStock || this == allocationConflict;

  static OrderStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in OrderStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return OrderStatus.allocating;
  }
}

enum PaymentMethod {
  unselected('', 'Chưa chọn phương thức'),
  prepaid('Prepaid', 'Trả trước (QR / tiền mặt)'),
  credit('Credit', 'Công nợ - trả sau');

  const PaymentMethod(this.code, this.label);
  final String code;
  final String label;

  static PaymentMethod fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final p in PaymentMethod.values) {
      if (p.code.toLowerCase() == c) return p;
    }
    return PaymentMethod.unselected;
  }

  String labelWithTerm(int creditTerm) => this == credit && creditTerm > 0
      ? 'Công nợ - trả sau $creditTerm ngày'
      : label;
}

/// State of an entry in the OfflineOrderQueue table.
enum SyncStatus {
  pending('pending', 'Chờ đồng bộ', StatusTone.neutral),
  syncing('syncing', 'Đang đồng bộ', StatusTone.info),
  synced('synced', 'Đã đồng bộ', StatusTone.success),
  rejected('rejected', 'Bị từ chối', StatusTone.danger);

  const SyncStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static SyncStatus fromCode(String? code) {
    for (final s in SyncStatus.values) {
      if (s.code == code) return s;
    }
    return SyncStatus.pending;
  }
}

enum ReceivableStatus {
  unpaid('Unpaid', 'Chưa thu', StatusTone.info),
  paid('Paid', 'Đã thu đủ', StatusTone.success),
  overdue('Overdue', 'Quá hạn', StatusTone.danger);

  const ReceivableStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static ReceivableStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in ReceivableStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return ReceivableStatus.unpaid;
  }
}

enum PickingStatus {
  pending('Pending', 'Chưa pick', StatusTone.info),
  picking('InProgress', 'Đang pick', StatusTone.purple),
  completed('Completed', 'Đã soạn xong', StatusTone.success),
  exception('Exception', 'Có ngoại lệ', StatusTone.danger);

  const PickingStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static PickingStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    if (c == 'picking') return PickingStatus.picking;
    if (c == 'shipped') return PickingStatus.completed;
    for (final s in PickingStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return PickingStatus.pending;
  }
}

enum LabelStatus {
  inStock('InStock', 'Trong kho', StatusTone.primary),
  picked('Picked', 'Đã pick', StatusTone.purple),
  inTransit('InTransit', 'Đang vận chuyển', StatusTone.warning),
  delivered('Delivered', 'Đã giao', StatusTone.success),
  expired('Expired', 'Hết hạn', StatusTone.danger),
  cancelled('Cancelled', 'Hủy', StatusTone.neutral);

  const LabelStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static LabelStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in LabelStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return LabelStatus.inStock;
  }
}

enum TransferKind {
  replenishment('Replenishment', 'Bổ sung tồn kho'),
  nearExpiryRotation('NearExpiryRotation', 'Luân chuyển cận hạn');

  const TransferKind(this.code, this.label);
  final String code;
  final String label;

  static TransferKind fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final k in TransferKind.values) {
      if (k.code.toLowerCase() == c) return k;
    }
    return TransferKind.replenishment;
  }
}

enum TransferStatus {
  inTransit('InTransit', 'Đang vận chuyển', StatusTone.warning),
  received('Received', 'Đã nhận', StatusTone.success),
  cancelled('Cancelled', 'Đã hủy', StatusTone.neutral);

  const TransferStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static TransferStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in TransferStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return TransferStatus.inTransit;
  }
}

enum GiftRequestStatus {
  requested('Requested', 'Chờ duyệt', StatusTone.info),
  approved('Approved', 'Đã duyệt', StatusTone.primary),
  delivered('Delivered', 'Đang giao quà', StatusTone.purple),
  done('Done', 'Hoàn tất', StatusTone.success),
  rejected('Rejected', 'Bị từ chối', StatusTone.danger);

  const GiftRequestStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static GiftRequestStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in GiftRequestStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return GiftRequestStatus.requested;
  }
}

enum PointKind {
  earned('Earned', 'Đã cộng'),
  pending('Pending', 'Chờ cộng'),
  held('Held', 'Đang giữ'),
  refunded('Refunded', 'Hoàn điểm'),
  redeemed('Redeemed', 'Đã đổi');

  const PointKind(this.code, this.label);
  final String code;
  final String label;

  static PointKind fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final k in PointKind.values) {
      if (k.code.toLowerCase() == c) return k;
    }
    return PointKind.earned;
  }
}

enum ComplaintStatus {
  open('Open', 'Chờ xử lý', StatusTone.info),
  inProgress('InProgress', 'Đang xử lý', StatusTone.purple),
  resolved('Resolved', 'Đã xử lý', StatusTone.success),
  rejected('Rejected', 'Từ chối', StatusTone.danger);

  const ComplaintStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static ComplaintStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in ComplaintStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return ComplaintStatus.open;
  }
}
// Retailer declaration status lives in retailer_declaration.dart
// (DeclarationStatus, matching backend RetailerStatuses).
