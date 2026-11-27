import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

class ComplaintFormScreen extends ConsumerStatefulWidget {
  const ComplaintFormScreen({
    super.key,
    this.orderCode,
    this.initialShipmentId,
  });
  final String? orderCode;
  final String? initialShipmentId;
  @override
  ConsumerState<ComplaintFormScreen> createState() =>
      _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends ConsumerState<ComplaintFormScreen> {
  String? _orderCode, _allocationId;
  String _issueType = 'Shortage';
  String _requestType = 'Complaint', _settlement = 'DebtOffset';
  bool _collect = false;
  final _actual = TextEditingController(), _note = TextEditingController();
  bool _busy = false;
  static const int _maxImages = 5;

  /// Images picked but not uploaded yet; bytes are kept so they can be previewed on any platform.
  final List<_PickedImage> _images = <_PickedImage>[];
  @override
  void initState() {
    super.initState();
    _orderCode = widget.orderCode;
  }

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final room = _maxImages - _images.length;
    if (room <= 0) {
      showAppSnack(context,
          'Tối đa $_maxImages ảnh. Hãy xóa bớt ảnh trước khi chọn thêm.',
          error: true);
      return;
    }
    final picked =
        await ImagePicker().pickMultiImage(imageQuality: 85, limit: room);
    if (picked.isEmpty) return;
    final added = <_PickedImage>[];
    for (final file in picked.take(room)) {
      added.add(_PickedImage(file, await file.readAsBytes()));
    }
    if (!mounted) return;
    setState(() => _images.addAll(added));
  }

  Future<void> _submit(
      Order order, ComplaintTarget target, String settlementMethod) async {
    if (_busy) return;
    // The field is the affected carton count (damaged/missing, or to return);
    // a Complaint still sends the usable count the Backend expects as actualQty.
    final entered = int.tryParse(_actual.text.trim());
    final affected = entered ?? 0;
    final actual = entered == null
        ? null
        : _requestType == 'Complaint'
            ? target.expectedQuantity - entered
            : entered;
    final claimLimit =
        target.remainingClaimableQuantity ?? target.expectedQuantity;
    final returnLimit = target.remainingReturnableQuantity ??
        target.receivedQuantity ??
        target.expectedQuantity;
    if (actual == null ||
        actual < 0 ||
        affected <= 0 ||
        affected > claimLimit ||
        ((_requestType != 'Complaint' || _collect) && affected > returnLimit)) {
      showAppSnack(context,
          'Số thùng không hợp lệ. Còn $claimLimit thùng được yêu cầu bồi hoàn, $returnLimit thùng được trả/thu hồi.',
          error: true);
      return;
    }
    if (_requestType != 'Complaint' && _note.text.trim().isEmpty) {
      showAppSnack(context, 'Vui lòng ghi rõ lý do trả/thu hồi hàng.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(loyaltyRepositoryProvider).complain(
          NewComplaint(
              orderCode: order.code,
              sku: target.sku,
              labelCode: target.labelCode,
              actualQty: actual,
              issueType: _issueType,
              note: _note.text.trim(),
              requestType: _requestType,
              settlementMethod: settlementMethod,
              affectedQuantity: _requestType == 'Complaint' ? null : affected,
              requiresCollection:
                  _requestType == 'DamagedCollection' || _collect,
              shipmentId: target.shipmentId,
              allocationId: target.allocationId));
      // The claim exists once created; images are attached to it afterwards.
      var failed = 0;
      for (final image in _images) {
        try {
          await ref.read(loyaltyRepositoryProvider).addComplaintEvidence(
              result.id, image.file.path,
              bytes: image.bytes, fileName: image.file.name);
        } on ApiException {
          failed++;
        }
      }
      ref.invalidate(complaintsProvider);
      ref.invalidate(complaintTargetsProvider(order.id));
      if (!mounted) return;
      showAppSnack(
          context,
          failed == 0
              ? 'Đã gửi yêu cầu ${result.code}.'
              : 'Đã gửi yêu cầu ${result.code} nhưng $failed ảnh chưa tải lên được. Hãy bổ sung ảnh trong danh sách yêu cầu.',
          error: failed > 0);
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Tạo yêu cầu')),
      body: AsyncBody<OrderListResult>(
          value: ref.watch(ordersProvider),
          onRetry: () => ref.invalidate(ordersProvider),
          builder: (result) {
            // The list API returns summaries. Receipt targets supply the actual SKU/batch/shipment.
            final eligible = result.orders
                .where((o) =>
                    o.code.isNotEmpty &&
                    [
                      OrderStatus.delivering,
                      OrderStatus.delivered,
                      OrderStatus.completed
                    ].contains(o.status))
                .toList();
            final matches = eligible.where((o) => o.code == _orderCode);
            final order = matches.isEmpty ? null : matches.first;
            // The order list has no payment amounts; the detail carries what was collected.
            final detail = order == null
                ? null
                : ref.watch(orderDetailProvider(order.code)).valueOrNull;
            final isCreditCollected = order != null &&
                order.payment == PaymentMethod.credit &&
                (detail?.confirmedAmount ?? order.confirmedAmount) > 0;
            // The server enforces the same mapping: prepaid is refunded, credit reduces debt.
            final lockedSettlement = order == null
                ? null
                : order.payment == PaymentMethod.prepaid
                    ? 'CashRefund'
                    : order.payment == PaymentMethod.credit
                        ? 'DebtOffset'
                        : null;
            final effectiveSettlement = lockedSettlement ?? _settlement;
            return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 32),
                children: [
                  const SectionTitle('Thông tin yêu cầu'),
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.s10,
                          children: [
                        DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _requestType,
                            decoration: const InputDecoration(
                                labelText: 'Loại yêu cầu'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Complaint',
                                  child: Text('Khiếu nại đơn hàng')),
                              DropdownMenuItem(
                                  value: 'Return', child: Text('Trả hàng')),
                              DropdownMenuItem(
                                  value: 'DamagedCollection',
                                  child: Text('Thu hồi hàng hỏng'))
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                      _requestType = v!;
                                      _collect = v != 'Complaint';
                                      _settlement = 'DebtOffset';
                                      _actual.clear();
                                      if (v != 'Complaint') {
                                        _issueType = 'Damaged';
                                      }
                                    })),
                        DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey(_orderCode),
                            initialValue: order?.code,
                            decoration: const InputDecoration(
                                labelText: 'Đơn đã giao / đang nhận hàng'),
                            items: eligible
                                .map((o) => DropdownMenuItem(
                                    value: o.code, child: Text(o.code)))
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                      _orderCode = v;
                                      _allocationId = null;
                                      _actual.clear();
                                    })),
                        if (eligible.isEmpty)
                          const Text('Chưa có đơn đã giao để khiếu nại.',
                              style: AppText.muted),
                      ])),
                  if (order != null) ...[
                    const SectionTitle('Chi tiết yêu cầu'),
                    AppCard(
                        child: ref
                            .watch(complaintTargetsProvider(order.id))
                            .when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, s) => TextButton(
                                    onPressed: () => ref.invalidate(
                                        complaintTargetsProvider(order.id)),
                                    child: const Text(
                                        'Không tải được phần hàng. Thử lại')),
                                data: (targets) {
                                  if (isCreditCollected) {
                                    return const InfoBanner(
                                      tone: StatusTone.warning,
                                      icon: Icons.lock_outline,
                                      text:
                                          'Đơn công nợ đã phát sinh thanh toán nên không thể tạo yêu cầu.',
                                    );
                                  }
                                  var chosen = targets.where(
                                      (t) => t.allocationId == _allocationId);
                                  if (chosen.isEmpty &&
                                      _allocationId == null &&
                                      widget.initialShipmentId != null) {
                                    chosen = targets.where((t) =>
                                        t.shipmentId ==
                                        widget.initialShipmentId);
                                  }
                                  final target =
                                      chosen.isEmpty ? null : chosen.first;
                                  return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: AppSpacing.s10,
                                      children: [
                                        if (targets.isEmpty)
                                          const Padding(
                                              padding:
                                                  EdgeInsets.all(AppSpacing.md),
                                              child: Text(
                                                  'Không còn phần hàng trong hạn gửi yêu cầu.')),
                                        DropdownButtonFormField<String>(
                                            key: ValueKey(
                                                '${order.id}:$_allocationId'),
                                            initialValue: target?.allocationId,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                                labelText:
                                                    'Sản phẩm · lô hàng · phần giao'),
                                            items: targets
                                                .map((t) => DropdownMenuItem(
                                                    value: t.allocationId,
                                                    child: Text(
                                                        '${t.sku} · ${t.batchCode} · ${t.shipmentCode}',
                                                        overflow: TextOverflow
                                                            .ellipsis)))
                                                .toList(),
                                            onChanged: _busy
                                                ? null
                                                : (v) => setState(() {
                                                      _allocationId = v;
                                                      _actual.clear();
                                                    })),
                                        if (target != null) ...[
                                          InfoBanner(
                                              icon: Icons.inventory_2_outlined,
                                              text:
                                                  '${target.productName}\nTem ${target.labelCode} · giao ${target.expectedQuantity} thùng\nHạn gửi: ${AppDates.timeDay(target.claimDeadline)}'),
                                          if (_requestType == 'Complaint')
                                            const SectionTitle('Lý do'),
                                          if (_requestType == 'Complaint')
                                            DropdownButtonFormField<String>(
                                                isExpanded: true,
                                                initialValue: _issueType,
                                                items: const [
                                                  DropdownMenuItem(
                                                      value: 'Shortage',
                                                      child:
                                                          Text('Thiếu hàng')),
                                                  DropdownMenuItem(
                                                      value: 'Damaged',
                                                      child: Text(
                                                          'Hàng hỏng / không sử dụng được'))
                                                ],
                                                onChanged: _busy
                                                    ? null
                                                    : (v) => setState(() {
                                                          _issueType =
                                                              v ?? 'Shortage';
                                                          if (_issueType ==
                                                              'Shortage') {
                                                            _collect = false;
                                                          }
                                                        })),
                                          const SectionTitle(
                                              'Phương án mong muốn'),
                                          DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              key: ValueKey(
                                                  'settlement:$_requestType:$effectiveSettlement'),
                                              initialValue: effectiveSettlement,
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      'Phương án mong muốn'),
                                              items: [
                                                const DropdownMenuItem(
                                                    value: 'DebtOffset',
                                                    child: Text(
                                                        'Cấn trừ công nợ')),
                                                const DropdownMenuItem(
                                                    value: 'CashRefund',
                                                    child: Text('Hoàn tiền')),
                                              ],
                                              onChanged: _busy || lockedSettlement != null
                                                  ? null
                                                  : (v) => setState(
                                                      () => _settlement = v!)),
                                          if (_requestType == 'Return' ||
                                              _requestType == 'Complaint' &&
                                                  _issueType == 'Damaged')
                                            CheckboxListTile(
                                                value: _collect,
                                                title: const Text(
                                                    'Cần công ty đến thu hồi hàng'),
                                                onChanged: _busy
                                                    ? null
                                                    : (v) => setState(() =>
                                                        _collect = v ?? false)),
                                          const InfoBanner(
                                              text:
                                                  'Đơn trả trước được hoàn tiền; đơn công nợ được cấn trừ vào công nợ của đơn. Quản trị viên xác nhận kết quả; yêu cầu xử lý hàng chờ đối soát thực tế.'),
                                          const SectionTitle(
                                              'Số lượng và mô tả'),
                                          TextField(
                                              key: const ValueKey(
                                                  'complaint_affected_quantity'),
                                              controller: _actual,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                  labelText: _requestType !=
                                                          'Complaint'
                                                      ? 'Số thùng yêu cầu trả / thu hồi'
                                                      : _issueType == 'Damaged'
                                                          ? 'Số thùng bị hỏng'
                                                          : 'Số thùng bị thiếu')),
                                          TextField(
                                              controller: _note,
                                              maxLines: 3,
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      'Mô tả thiếu / hư hỏng')),
                                          const SectionTitle('Ảnh bằng chứng'),
                                          if (_images.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: AppSpacing.sm),
                                              child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: <Widget>[
                                                    for (var i = 0;
                                                        i < _images.length;
                                                        i++)
                                                      _ImagePreview(
                                                        bytes: _images[i].bytes,
                                                        onRemove: _busy
                                                            ? null
                                                            : () => setState(
                                                                () => _images
                                                                    .removeAt(
                                                                        i)),
                                                      ),
                                                  ]),
                                            ),
                                          OutlinedButton.icon(
                                              onPressed: _busy ||
                                                      _images.length >=
                                                          _maxImages
                                                  ? null
                                                  : _pickImages,
                                              icon: const Icon(
                                                  Icons.add_a_photo_outlined),
                                              label: Text(_images.isEmpty
                                                  ? 'Thêm ảnh bằng chứng (tối đa $_maxImages)'
                                                  : 'Thêm ảnh · ${_images.length}/$_maxImages')),
                                          const SizedBox(height: AppSpacing.xs),
                                          FilledButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _submit(order, target,
                                                      effectiveSettlement),
                                              child: Text(_busy
                                                  ? 'Đang gửi...'
                                                  : 'Gửi yêu cầu')),
                                        ],
                                      ]);
                                })),
                  ],
                ]);
          }));
}

class _PickedImage {
  const _PickedImage(this.file, this.bytes);
  final XFile file;
  final Uint8List bytes;
}

/// Local preview of a picked image with a remove button.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 84, height: 84, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ]);
}
