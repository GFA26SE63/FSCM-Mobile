import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';

class ComplaintFormScreen extends ConsumerStatefulWidget {
  const ComplaintFormScreen({super.key, this.orderCode});
  final String? orderCode;
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

  Future<void> _submit(Order order, ComplaintTarget target) async {
    if (_busy) return;
    final actual = int.tryParse(_actual.text.trim());
    final affected = actual == null
        ? 0
        : _requestType == 'Complaint'
            ? target.expectedQuantity - actual
            : actual;
    final claimLimit =
        target.remainingClaimableQuantity ?? target.expectedQuantity;
    final returnLimit = target.remainingReturnableQuantity ??
        target.receivedQuantity ??
        target.expectedQuantity;
    if (actual == null ||
        actual < 0 ||
        affected <= 0 ||
        (_settlement != 'None' && affected > claimLimit) ||
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
              settlementMethod: _settlement,
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
            return ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                  initialValue: _requestType,
                  decoration: const InputDecoration(labelText: 'Loại yêu cầu'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Complaint', child: Text('Khiếu nại đơn hàng')),
                    DropdownMenuItem(value: 'Return', child: Text('Trả hàng')),
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
                            if (v != 'Complaint') _issueType = 'Damaged';
                          })),
              DropdownButtonFormField<String>(
                  key: ValueKey(_orderCode),
                  initialValue: order?.code,
                  decoration: const InputDecoration(
                      labelText: 'Đơn đã giao / đang nhận hàng'),
                  items: eligible
                      .map((o) =>
                          DropdownMenuItem(value: o.code, child: Text(o.code)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                            _orderCode = v;
                            _allocationId = null;
                            _actual.clear();
                          })),
              if (eligible.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Chưa có đơn đã giao để khiếu nại.')),
              if (order != null)
                ref.watch(complaintTargetsProvider(order.id)).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => TextButton(
                        onPressed: () =>
                            ref.invalidate(complaintTargetsProvider(order.id)),
                        child: const Text('Không tải được phần hàng. Thử lại')),
                    data: (targets) {
                      final chosen =
                          targets.where((t) => t.allocationId == _allocationId);
                      final target = chosen.isEmpty ? null : chosen.first;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (targets.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                      'Không còn phần hàng đã nhận đủ điều kiện khiếu nại.')),
                            DropdownButtonFormField<String>(
                                key: ValueKey('${order.id}:$_allocationId'),
                                initialValue: target?.allocationId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Sản phẩm · batch · phần giao'),
                                items: targets
                                    .map((t) => DropdownMenuItem(
                                        value: t.allocationId,
                                        child: Text(
                                            '${t.sku} · ${t.batchCode} · ${t.shipmentCode}',
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() {
                                          _allocationId = v;
                                          _actual.clear();
                                        })),
                            if (target != null) ...[
                              Text(
                                  '${target.productName}\nTem ${target.labelCode} · giao ${target.expectedQuantity} thùng'),
                              if (_requestType == 'Complaint')
                                DropdownButtonFormField<String>(
                                    initialValue: _issueType,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Shortage',
                                          child: Text('Thiếu hàng')),
                                      DropdownMenuItem(
                                          value: 'Damaged',
                                          child: Text(
                                              'Hàng hỏng / không sử dụng được'))
                                    ],
                                    onChanged: _busy
                                        ? null
                                        : (v) => setState(() {
                                              _issueType = v ?? 'Shortage';
                                              if (_issueType == 'Shortage') {
                                                _collect = false;
                                              }
                                            })),
                              DropdownButtonFormField<String>(
                                  key: ValueKey('settlement:$_requestType'),
                                  initialValue: _settlement,
                                  decoration: const InputDecoration(
                                      labelText: 'Phương án mong muốn'),
                                  items: [
                                    const DropdownMenuItem(
                                        value: 'DebtOffset',
                                        child: Text('Cấn trừ công nợ')),
                                    const DropdownMenuItem(
                                        value: 'CashRefund',
                                        child: Text('Hoàn tiền')),
                                    if (_requestType == 'DamagedCollection')
                                      const DropdownMenuItem(
                                          value: 'None',
                                          child: Text(
                                              'Chỉ thu hồi, không bồi hoàn'))
                                  ],
                                  onChanged: _busy
                                      ? null
                                      : (v) =>
                                          setState(() => _settlement = v!)),
                              if (_requestType == 'Return' ||
                                  _requestType == 'Complaint' &&
                                      _issueType == 'Damaged')
                                CheckboxListTile(
                                    value: _collect,
                                    title: const Text(
                                        'Cần công ty đến thu hồi hàng'),
                                    onChanged: _busy
                                        ? null
                                        : (v) => setState(
                                            () => _collect = v ?? false)),
                              const Text(
                                  'Giảm nợ trong đơn gốc trước; phần tiền đã thu thừa được lập phiếu hoàn. Admin xác nhận phương án; yêu cầu xử lý hàng chờ đối soát thực tế.'),
                              TextField(
                                  controller: _actual,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: _requestType == 'Complaint'
                                          ? 'Số thùng dùng được trong phần giao này'
                                          : 'Số thùng yêu cầu trả / thu hồi')),
                              TextField(
                                  controller: _note,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'Mô tả thiếu / hư hỏng')),
                              if (_images.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: <Widget>[
                                        for (var i = 0; i < _images.length; i++)
                                          _ImagePreview(
                                            bytes: _images[i].bytes,
                                            onRemove: _busy
                                                ? null
                                                : () => setState(
                                                    () => _images.removeAt(i)),
                                          ),
                                      ]),
                                ),
                              OutlinedButton.icon(
                                  onPressed:
                                      _busy || _images.length >= _maxImages
                                          ? null
                                          : _pickImages,
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: Text(_images.isEmpty
                                      ? 'Thêm ảnh bằng chứng (tối đa $_maxImages)'
                                      : 'Thêm ảnh · ${_images.length}/$_maxImages')),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _submit(order, target),
                                  child: Text(
                                      _busy ? 'Đang gửi...' : 'Gửi yêu cầu')),
                            ],
                          ]);
                    }),
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
