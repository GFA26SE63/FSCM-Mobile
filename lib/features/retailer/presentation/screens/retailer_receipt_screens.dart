import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/retailer/domain/retailer_models.dart';
import 'package:fmcg/features/retailer/presentation/retailer_scope.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_orders_screen.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

class RetailerScanHubScreen extends StatelessWidget {
  const RetailerScanHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final delivering = controller.orders
        .where((order) => order.status == SalesOrderStatus.delivering)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR nhận hàng')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ScanFrame(
            message:
                'Quét tem trên kiện hàng. Hệ thống sẽ kiểm tra tem có thuộc đơn của điểm bán này hay không.',
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: delivering == null
                ? null
                : () => _handleResult(
                    context,
                    controller.scanLabel(delivering, 'TEM-OTHER-001'),
                  ),
            icon: const Icon(Icons.error_outline),
            label: const Text('Giả lập tem của cửa hàng khác'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            key: const Key('retailerValidScanButton'),
            onPressed: delivering == null
                ? null
                : () {
                    final result = controller.scanLabel(
                      delivering,
                      'TEM-000187',
                    );
                    _handleResult(context, result);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RetailerReceiptScanScreen(orderId: delivering.id),
                      ),
                    );
                  },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Giả lập quét TEM-000187'),
          ),
          if (delivering == null)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Text(
                'Hiện không có đơn đang giao cần nhận.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FscmColors.muted),
              ),
            ),
        ],
      ),
    );
  }

  void _handleResult(BuildContext context, LabelScanResult result) {
    final message = switch (result) {
      LabelScanResult.matched => 'Tem hợp lệ và đã được ghi nhận.',
      LabelScanResult.alreadyScanned => 'Tem này đã được quét.',
      LabelScanResult.wrongRetailer =>
        'Tem thuộc cửa hàng khác. Không thể nhận kiện này.',
      LabelScanResult.unknown => 'Không tìm thấy tem trong phiếu xuất.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class RetailerReceiptScanScreen extends StatelessWidget {
  const RetailerReceiptScanScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final order = controller.orderById(orderId);
    if (order == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy đơn hàng.')),
      );
    }
    final labels = controller.labelsFor(order);
    final scanned = controller.scannedFor(order.id);
    final complete = controller.allLabelsScanned(order);

    return Scaffold(
      appBar: AppBar(title: Text('Nhận hàng ${order.id}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: FscmColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Đã quét ${scanned.length}/${labels.length} tem',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: labels.isEmpty ? 0 : scanned.length / labels.length,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đối chiếu mã batch và số lượng trên từng kiện với phiếu xuất.',
                  style: TextStyle(color: FscmColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...labels.map((batch) {
            final matched = scanned.contains(batch.labelCode);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FscmCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: matched
                          ? const Color(0xFF15703A)
                          : FscmColors.border,
                      child: Icon(
                        matched ? Icons.check : Icons.qr_code_2,
                        size: 16,
                        color: matched ? Colors.white : FscmColors.muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            batch.labelCode ?? batch.batchCode,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            batch.batchCode,
                            style: const TextStyle(
                              fontSize: 12,
                              color: FscmColors.muted,
                            ),
                          ),
                          Text(
                            '${batch.quantity} thùng · HSD ${batch.expiryDate} · ${batch.warehouse}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: FscmColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      matched ? 'Khớp' : 'Chưa quét',
                      style: TextStyle(
                        color: matched
                            ? const Color(0xFF15703A)
                            : FscmColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          if (!complete)
            ElevatedButton.icon(
              key: const Key('scanNextPackageButton'),
              onPressed: () {
                controller.scanNext(order);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã quét tem tiếp theo · batch và số lượng khớp.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét tem tiếp theo'),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RetailerComplaintScreen(orderId: order.id),
              ),
            ),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Gửi khiếu nại số lượng / chất lượng'),
          ),
        ],
      ),
      bottomSheet: BottomActionBar(
        child: ElevatedButton(
          key: const Key('confirmReceiptButton'),
          onPressed: complete
              ? () {
                  controller.confirmReceipt(order);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RetailerReceiptSuccessScreen(orderId: order.id),
                    ),
                  );
                }
              : null,
          child: Text(
            complete
                ? 'Xác nhận đã nhận đủ hàng'
                : 'Quét đủ ${labels.length} tem để xác nhận',
          ),
        ),
      ),
    );
  }
}

class RetailerReceiptSuccessScreen extends StatelessWidget {
  const RetailerReceiptSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final order = RetailerScope.of(context).orderById(orderId);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1F1EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: FscmColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Đơn hàng đã hoàn thành',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '$orderId đã được đối chiếu đủ batch và số lượng.${order?.payment.method == PaymentMethod.cod ? ' Thanh toán COD đã được ghi nhận.' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: FscmColors.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  RetailerScope.of(context, listen: false).setTab(0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Về danh sách đơn hàng'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => RetailerOrderDetailScreen(orderId: orderId),
                  ),
                ),
                child: const Text('Xem chi tiết đơn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RetailerComplaintScreen extends StatefulWidget {
  const RetailerComplaintScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<RetailerComplaintScreen> createState() =>
      _RetailerComplaintScreenState();
}

class _RetailerComplaintScreenState extends State<RetailerComplaintScreen> {
  BatchAllocation? _batch;
  final _actualController = TextEditingController();
  final _noteController = TextEditingController();
  int _evidenceCount = 0;

  @override
  void dispose() {
    _actualController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = RetailerScope.of(context);
    final order = controller.orderById(widget.orderId)!;
    final batches = order.lines.expand((line) => line.batches).toList();
    _batch ??= batches.firstOrNull;
    final canSubmit =
        _batch != null &&
        int.tryParse(_actualController.text) != null &&
        _evidenceCount > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Gửi khiếu nại')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Chọn batch có vấn đề',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<BatchAllocation>(
            initialValue: _batch,
            items: batches
                .map(
                  (batch) => DropdownMenuItem(
                    value: batch,
                    child: Text('${batch.batchCode} · ${batch.quantity} thùng'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _batch = value),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _actualController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Số lượng thực nhận'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mô tả số lượng / chất lượng không phù hợp',
            ),
          ),
          const SizedBox(height: 14),
          EvidencePickerCard(
            count: _evidenceCount,
            onAdd: () => setState(() => _evidenceCount++),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: canSubmit
                ? () {
                    controller.submitComplaint(
                      RetailerComplaint(
                        orderId: order.id,
                        batchCode: _batch!.batchCode,
                        expectedQuantity: _batch!.quantity,
                        actualQuantity: int.parse(_actualController.text),
                        note: _noteController.text.trim(),
                        evidenceCount: _evidenceCount,
                      ),
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã gửi khiếu nại cho Operator và Warehouse Keeper.',
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text('Gửi khiếu nại'),
          ),
        ],
      ),
    );
  }
}
