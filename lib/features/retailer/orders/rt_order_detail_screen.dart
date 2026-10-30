import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/order_widgets.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/timeline_list.dart';

/// Retailer order detail screen matching `FSCM_Prototype_Prod_v1.1.html`
/// (`DEFS.retailer` ORDER DETAIL + Quote Accept/Reject + Prepaid Transfer).
class RtOrderDetailScreen extends ConsumerStatefulWidget {
  const RtOrderDetailScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<RtOrderDetailScreen> createState() =>
      _RtOrderDetailScreenState();
}

class _RtOrderDetailScreenState extends ConsumerState<RtOrderDetailScreen> {
  bool _quoteAccepted = false;
  bool _quoteRejected = false;
  String _quoteRejectReason = '';
  PaymentMethod? _chosenPayment;
  bool _prepaidSubmitted = false;
  String _txId = '';

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(orderDetailProvider(widget.code));
    return AsyncBody<Order>(
      value: value,
      onRetry: () => ref.invalidate(orderDetailProvider(widget.code)),
      builder: (o) {
        final effectivePayment = _chosenPayment ?? o.payment;
        final isPendingQuote = o.status == OrderStatus.pending &&
            !_quoteAccepted &&
            !_quoteRejected;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Đơn ${o.code}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Lập lúc ${AppDates.timeDay(o.createdAt)} · Sales Nguyễn Văn An',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Trạng thái',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        OrderStatusChip(o),
                      ],
                    ),
                    const SizedBox(height: 6),
                    KvRow(
                      'Hình thức thanh toán',
                      effectivePayment.labelWithTerm(o.creditTerm),
                    ),
                    if (effectivePayment == PaymentMethod.credit &&
                        o.dueDate != null)
                      KvRow('Hạn thanh toán', AppDates.date(o.dueDate)),
                    if (o.status == OrderStatus.rejected || _quoteRejected)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _quoteRejected
                                ? 'Lý do từ chối báo giá: $_quoteRejectReason'
                                : 'Lý do từ chối: ${o.rejectReason.isEmpty ? 'Hệ thống từ chối đơn hàng.' : o.rejectReason}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ),
                    if (isPendingQuote) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEFD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB9CBEF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Báo giá BG-${o.code.replaceAll('ORD-', '')} · hạn phản hồi 16/09/2026 12:00',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Nhà phân phối đã gửi báo giá chính thức (đã khóa tồn kho & tính khuyến mãi). Vui lòng kiểm tra và phản hồi trước hạn.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(
                                  color: AppColors.danger,
                                  width: 1.5,
                                ),
                              ),
                              onPressed: () => _showRejectQuoteSheet(o),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Từ chối'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _showChoosePaymentSheet(o),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Chấp nhận báo giá'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((effectivePayment == PaymentMethod.prepaid &&
                            !o.paid &&
                            !_prepaidSubmitted &&
                            !_quoteRejected &&
                            o.status != OrderStatus.rejected &&
                            o.status != OrderStatus.cancelled) &&
                        !isPendingQuote) ...<Widget>[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _openPrepaidTransferSheet(o),
                        icon: const Icon(Icons.qr_code_2, size: 18),
                        label: Text(
                          'Thanh toán chuyển khoản (${Money.format(o.finalAmount)})',
                        ),
                      ),
                    ],
                    if (_prepaidSubmitted) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Chứng từ chuyển khoản (Mã GD: $_txId) đã gửi · đang chờ Kế toán xác nhận để kho xuất hàng.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (o.hasDelivery) DeliveryInfoCard(o),
              if (o.status.canConfirmReceipt)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: () => context.push(AppRoutes.rtReceive(o.code)),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Quét QR xác nhận nhận hàng'),
                  ),
                ),
              if (o.status == OrderStatus.delivered ||
                  o.status == OrderStatus.completed)
                _receiptBanner(o),
              SectionTitle('Mặt hàng (${o.lines.length})'),
              OrderLinesCard(o, showBatches: o.status != OrderStatus.rejected),
              const SectionTitle('Khuyến mãi áp dụng'),
              AppliedPromoCard(
                o.appliedPromos,
                emptyText: 'Không có khuyến mãi.',
              ),
              const SizedBox(height: 10),
              TotalsCard(total: o.total, discount: o.discount),
              if (o.timeline.isNotEmpty) ...<Widget>[
                const SectionTitle('Tiến trình đơn hàng'),
                AppCard(child: TimelineList(o.timeline)),
              ],
              if (o.status == OrderStatus.delivered ||
                  o.status == OrderStatus.completed)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.rtComplaintFor(o.code)),
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                  label: const Text('Gửi khiếu nại về đơn này'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRejectQuoteSheet(Order o) async {
    const reasons = <String>[
      'Giá chưa phù hợp',
      'Thời gian giao không kịp',
      'Đã mua nguồn khác',
      'Đặt nhầm số lượng',
    ];
    String selected = reasons.first;
    final ctrl = TextEditingController(text: selected);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5D1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Từ chối báo giá · ${o.code}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Đơn sẽ chuyển sang Đã hủy và giải phóng hàng đã giữ.',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final r in reasons)
                        ChoiceChip(
                          label: Text(r, style: const TextStyle(fontSize: 12)),
                          selected: selected == r,
                          onSelected: (_) {
                            setSheetState(() {
                              selected = r;
                              ctrl.text = r;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lý do từ chối *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Nhập lý do từ chối báo giá...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Quay lại'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger,
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _quoteRejected = true;
                              _quoteRejectReason = ctrl.text.trim().isEmpty
                                  ? selected
                                  : ctrl.text.trim();
                            });
                            showAppSnack(
                              context,
                              'Đã từ chối báo giá đơn ${o.code}.',
                            );
                          },
                          child: const Text('Từ chối và hủy đơn'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showChoosePaymentSheet(Order o) async {
    PaymentMethod selected = PaymentMethod.prepaid;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5D1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Chấp nhận báo giá · ${o.code}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chọn hình thức thanh toán cho đơn ${Money.format(o.finalAmount)}.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PaymentOptionTile(
                    title: 'Trả trước – chuyển khoản',
                    subtitle:
                        'Chuyển khoản theo QR ngân hàng và gửi chứng từ xác nhận. Kho xuất hàng sau khi Kế toán xác nhận đã nhận tiền.',
                    selected: selected == PaymentMethod.prepaid,
                    onTap: () =>
                        setSheetState(() => selected = PaymentMethod.prepaid),
                  ),
                  const SizedBox(height: 8),
                  _PaymentOptionTile(
                    title: 'Công nợ – trả sau 14 ngày',
                    subtitle:
                        'Kho chuẩn bị hàng ngay. Thanh toán 1 lần toàn bộ giá trị đơn trong 14 ngày kể từ khi nhận hàng.',
                    selected: selected == PaymentMethod.credit,
                    onTap: () =>
                        setSheetState(() => selected = PaymentMethod.credit),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _quoteAccepted = true;
                              _chosenPayment = selected;
                            });
                            if (selected == PaymentMethod.prepaid) {
                              _openPrepaidTransferSheet(o);
                            } else {
                              showAppSnack(
                                context,
                                'Đã chấp nhận báo giá · Công nợ 14 ngày.',
                              );
                            }
                          },
                          child: const Text('Xác nhận'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPrepaidTransferSheet(Order o) async {
    final txCtrl = TextEditingController(text: 'VCB92837465');
    final noteCtrl = TextEditingController();
    String proofName = 'unc_${o.code.toLowerCase()}.jpg';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Thanh toán đơn ${o.code}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Text(
                                'Trả trước · chuyển khoản ngân hàng',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        children: <Widget>[
                          const Text(
                            'Số tiền cần chuyển',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Money.format(o.finalAmount),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.qr_code_2,
                              size: 120,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Quét VietQR bằng ứng dụng ngân hàng',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      child: Column(
                        children: <Widget>[
                          const KvRow('Ngân hàng', 'Vietcombank · CN TP.HCM'),
                          const KvRow('Số tài khoản', '0071 0012 3456'),
                          const KvRow(
                            'Chủ tài khoản',
                            'CÔNG TY PHÂN PHỐI FSCM',
                          ),
                          KvRow(
                            'Nội dung CK',
                            'FSCM ${o.code} 10004127',
                            valueColor: AppColors.primary,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Gửi chứng từ chuyển khoản',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mã giao dịch ngân hàng *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: txCtrl,
                            decoration: const InputDecoration(
                              hintText: 'VD: FT26258123456',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ảnh chụp màn hình / ủy nhiệm chi *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                proofName = 'unc_${o.code.toLowerCase()}.jpg';
                              });
                            },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: Text(
                              proofName.isEmpty
                                  ? 'Đính kèm ảnh chứng từ'
                                  : 'Đã đính kèm: $proofName',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ghi chú (tùy chọn)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: noteCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Ghi chú thêm cho kế toán...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () {
                        if (txCtrl.text.trim().isEmpty) return;
                        Navigator.of(ctx).pop();
                        setState(() {
                          _prepaidSubmitted = true;
                          _txId = txCtrl.text.trim();
                        });
                        showAppSnack(
                          context,
                          'Đã gửi chứng từ chuyển khoản cho Kế toán.',
                        );
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Gửi chứng từ chuyển khoản'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _receiptBanner(Order o) {
    if (o.pointsEarned <= 0) return const SizedBox.shrink();
    return InfoBanner(
      tone: StatusTone.success,
      icon: Icons.stars_outlined,
      title: o.pointsPending
          ? '+${o.pointsEarned} điểm đang chờ cộng'
          : '+${o.pointsEarned} điểm đã cộng',
      text: o.pointsPending
          ? 'Đơn công nợ: điểm được cộng khi bạn thanh toán đủ.'
          : 'Điểm tích lũy từ đơn hàng này đã vào tài khoản.',
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
