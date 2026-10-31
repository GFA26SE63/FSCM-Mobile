import 'package:fscm_mobile/core/utils/status_tone.dart';

/// Status vocabulary from SPEC section 9: `code` is the API value,
/// `label` the Vietnamese UI text.

enum OrderStatus {
  pending('Pending', 'Chờ duyệt', StatusTone.info),
  approved('Approved', 'Đã duyệt', StatusTone.primary),
  picking('Picking', 'Đang soạn hàng', StatusTone.purple),
  shipped('Shipped', 'Đã xuất kho', StatusTone.primary),
  delivering('Delivering', 'Đang giao', StatusTone.purple),
  delivered('Delivered', 'Đã giao', StatusTone.success),
  completed('Completed', 'Hoàn tất', StatusTone.success),
  rejected('Rejected', 'Bị từ chối', StatusTone.danger),
  cancelled('Cancelled', 'Đã hủy', StatusTone.neutral);

  const OrderStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  /// Not yet delivered / closed (retailer "đang xử lý" tab).
  bool get isActive =>
      this == pending ||
      this == approved ||
      this == picking ||
      this == shipped ||
      this == delivering;

  /// Retailer may still scan the QR to confirm receipt.
  bool get canConfirmReceipt => this == delivering || this == shipped;

  static OrderStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in OrderStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return OrderStatus.pending;
  }
}

enum PaymentMethod {
  cod('COD', 'Khi nhận hàng (COD)'),
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
    return PaymentMethod.cod;
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
  pending('Pending', 'Chưa soạn', StatusTone.info),
  picking('Picking', 'Đang soạn', StatusTone.purple),
  shipped('Shipped', 'Đã xuất', StatusTone.success);

  const PickingStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static PickingStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in PickingStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return PickingStatus.pending;
  }
}

enum LabelStatus {
  inStock('InStock', 'Trong kho', StatusTone.primary),
  picked('Picked', 'Đã soạn', StatusTone.purple),
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
    if (c == 'pending') return GiftRequestStatus.requested;
    if (c == 'completed') return GiftRequestStatus.done;
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

/// Retailer registration request (KB-0000) state.
enum RegistrationStatus {
  waiting('Pending', 'Chờ duyệt', StatusTone.info),
  approved('Approved', 'Đã duyệt', StatusTone.success),
  rejected('Rejected', 'Bị từ chối', StatusTone.danger);

  const RegistrationStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static RegistrationStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in RegistrationStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return RegistrationStatus.waiting;
  }
}

/// Status of one warehouse's picking sheet for a run (F43).
///
/// `Ready` is the end of picking, not the end of the order: the cartons are on
/// the dock but nothing has left and no stock has moved. `NeedsHandling` is a
/// sheet someone closed with an exception, which holds the whole order.
enum SheetStatus {
  issued('Issued', 'Mới phát hành', StatusTone.info),
  picking('Picking', 'Đang soạn', StatusTone.purple),
  ready('Ready', 'Soạn xong', StatusTone.primary),
  needsHandling('NeedsHandling', 'Cần xử lý', StatusTone.danger);

  const SheetStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static SheetStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in SheetStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return SheetStatus.issued;
  }
}

/// Status of one gather on a sheet. There are only two: the approved quantity
/// has been taken off the batch, or it has not.
enum GatherStatus {
  pending('Pending', 'Chưa lấy', StatusTone.neutral),
  picked('Picked', 'Đã lấy', StatusTone.success);

  const GatherStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  static GatherStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in GatherStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return GatherStatus.pending;
  }
}

/// Status of one warehouse's part of an order (F93, F96). `Issued` is the only
/// one that means stock has actually moved.
enum ShipmentPartStatus {
  waitingToPick('WaitingToPick', 'Chờ soạn', StatusTone.info),
  ready('Ready', 'Sẵn sàng', StatusTone.primary),
  issued('Issued', 'Đã xuất', StatusTone.success),
  delivering('Delivering', 'Đang giao', StatusTone.purple),
  received('Received', 'Đã nhận', StatusTone.success),
  exception('Exception', 'Ngoại lệ', StatusTone.danger);

  const ShipmentPartStatus(this.code, this.label, this.tone);
  final String code;
  final String label;
  final StatusTone tone;

  bool get hasLeft =>
      this == ShipmentPartStatus.issued ||
      this == ShipmentPartStatus.delivering ||
      this == ShipmentPartStatus.received;

  static ShipmentPartStatus fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    for (final s in ShipmentPartStatus.values) {
      if (s.code.toLowerCase() == c) return s;
    }
    return ShipmentPartStatus.waitingToPick;
  }
}
