import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

/// One manual refund record of the signed-in retailer, read from the order's
/// receivable view (`refunds` history). Read-only: Operator records the
/// transfer, Admin verifies it.
class RetailerRefund {
  const RetailerRefund({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    this.transferredAt,
    this.transactionReference = '',
    this.verifiedAt,
    this.reason = '',
    this.evidenceUrl = '',
  });

  /// [order] is the receivable row that holds this refund in its `refunds`.
  factory RetailerRefund.fromJson(
          Map<String, dynamic> j, Map<String, dynamic> order) =>
      RetailerRefund(
        id: asStr(j['id']),
        orderId: asStr(order['orderId']),
        orderCode: asStr(order['orderCode']),
        paymentMethod: asStr(order['paymentMethod']),
        amount: asDouble(j['amount']),
        status: asStr(j['status']),
        transferredAt: asDate(j['transferredAt']),
        transactionReference: asStr(j['transactionReference']),
        verifiedAt: asDate(j['verifiedAt']),
        reason: asStr(j['reason']),
        evidenceUrl: asStr(j['evidenceUrl']),
      );

  final String id, orderId, orderCode, paymentMethod, status;
  final double amount;
  final DateTime? transferredAt, verifiedAt;
  final String transactionReference, reason;

  /// Short-lived read URL of the transfer-proof image; empty when none.
  final String evidenceUrl;

  /// `PendingRefund → AwaitingVerification → Refunded`, `EvidenceRejected` branch.
  bool get isOpen => status != 'Refunded';

  // Same labels as the Web refund pages.
  String get statusText => switch (status) {
        'PendingRefund' => 'Chờ hoàn',
        'AwaitingVerification' => 'Chờ quản trị viên xác minh',
        'EvidenceRejected' => 'Bằng chứng bị trả lại',
        'Refunded' => 'Đã hoàn',
        _ => status,
      };

  StatusTone get statusTone => switch (status) {
        'PendingRefund' => StatusTone.warning,
        'AwaitingVerification' => StatusTone.info,
        'EvidenceRejected' => StatusTone.danger,
        'Refunded' => StatusTone.success,
        _ => StatusTone.neutral,
      };

  String get paymentText => paymentMethod == 'Prepaid'
      ? 'Trả trước'
      : paymentMethod == 'Credit'
          ? 'Công nợ'
          : paymentMethod;
}

/// Drops records loaded twice (an order fetched from both sources) and puts
/// unfinished refunds first, newest order code first within each group.
List<RetailerRefund> mergeRetailerRefunds(Iterable<RetailerRefund> refunds) {
  final byId = <String, RetailerRefund>{for (final r in refunds) r.id: r};
  return byId.values.toList()
    ..sort((a, b) => a.isOpen != b.isOpen
        ? (a.isOpen ? -1 : 1)
        : b.orderCode.compareTo(a.orderCode));
}
