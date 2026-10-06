import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/warehouse/data/demo_warehouse_data.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_presenters.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_scope.dart';
import 'package:fmcg/shared/widgets/inventory_widgets.dart';

class WarehouseReceiveScreen extends StatefulWidget {
  const WarehouseReceiveScreen({super.key});

  @override
  State<WarehouseReceiveScreen> createState() => _WarehouseReceiveScreenState();
}

class _WarehouseReceiveScreenState extends State<WarehouseReceiveScreen> {
  final _documentController = TextEditingController(text: 'HD-VNM-092901');
  final _expiryController = TextEditingController(text: '19/10/2026');
  final _quantityController = TextEditingController(text: '120');
  final _lotController = TextEditingController();
  String _sku = 'SKU006';
  int _labelCount = 2;

  @override
  void dispose() {
    _documentController.dispose();
    _expiryController.dispose();
    _quantityController.dispose();
    _lotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final compactExpiry = _expiryController.text.replaceAll('/', '');
    final batchCode = '${DemoWarehouseData.warehouseCode}-$_sku-$compactExpiry';
    final preview = _splitQuantities(quantity, _labelCount);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập kho'),
            Text(
              'Kho Thới An · phiếu nhập mới',
              style: TextStyle(
                color: FscmColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          TextField(
            controller: _documentController,
            decoration: const InputDecoration(
              labelText: 'Số chứng từ nhà cung cấp',
            ),
          ),
          const SizedBox(height: 14),
          const Text('SKU', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DemoWarehouseData.productNames.keys
                .map(
                  (sku) => ChoiceChip(
                    label: Text(sku),
                    selected: _sku == sku,
                    onSelected: (_) => setState(() => _sku = sku),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          Text(
            DemoWarehouseData.productNames[_sku]!,
            style: const TextStyle(color: FscmColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Hạn sử dụng'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Tổng số thùng'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F5),
              border: Border.all(color: FscmColors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Batch ID – hệ thống tự sinh',
                  style: TextStyle(color: FscmColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  batchCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Mã kho + SKU + HSD (ddMMyyyy)',
                  style: TextStyle(color: FscmColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _lotController,
            decoration: InputDecoration(
              labelText: 'Lô NSX (tùy chọn)',
              hintText: 'Quét mã lô hoặc nhập tay',
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _lotController.text = 'L2609-${_sku.substring(3)}',
                ),
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Số tem (pallet)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    QuantityStepper(
                      value: _labelCount,
                      maximum: 10,
                      onChanged: (value) => setState(() => _labelCount = value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  quantity > 0
                      ? 'Sẽ tạo: ${preview.indexed.map((item) => 'Tem ${item.$1 + 1} = ${item.$2} thùng').join(' · ')}'
                      : 'Nhập tổng số thùng để xem phân bổ tem.',
                  style: const TextStyle(
                    color: FscmColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: BottomActionBar(
        child: ElevatedButton(
          key: const Key('saveWarehouseReceiptButton'),
          onPressed:
              quantity >= _labelCount &&
                  _expiryController.text.isNotEmpty &&
                  _documentController.text.isNotEmpty
              ? () {
                  final receipt = WarehouseScope.of(context, listen: false)
                      .receiveStock(
                        supplierDocument: _documentController.text.trim(),
                        sku: _sku,
                        expiryDate: _expiryController.text.trim(),
                        quantity: quantity,
                        labelCount: _labelCount,
                        manufacturerLot: _lotController.text.trim(),
                      );
                  if (receipt == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          WarehouseReceiptDoneScreen(receipt: receipt),
                    ),
                  );
                }
              : null,
          child: Text('Lưu phiếu & in $_labelCount tem'),
        ),
      ),
    );
  }

  List<int> _splitQuantities(int quantity, int count) => List.generate(
    count,
    (index) => quantity ~/ count + (index < quantity % count ? 1 : 0),
  );
}

class WarehouseReceiptDoneScreen extends StatelessWidget {
  const WarehouseReceiptDoneScreen({super.key, required this.receipt});

  final GoodsReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final labels = receipt.labelIds
        .map(controller.labelById)
        .whereType<StockLabel>()
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Đã nhập ${receipt.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F4EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Đã tạo batch ${receipt.batchCode}, tăng tồn ${receipt.quantity} thùng và gửi lệnh in ${labels.length} tem.',
              style: const TextStyle(color: Color(0xFF14532D), height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          ...labels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InventoryLabelCard(
                labelId: label.id,
                sku: label.sku,
                quantity: label.quantity,
                batchCode: label.batchCode,
                expiryDate: label.expiryDate,
                location: label.location,
                status: stockStatusLabel(label.status),
                statusColor: stockStatusColor(label.status),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã gửi in lại ${labels.length} tem.')),
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('In lại tất cả tem'),
          ),
        ],
      ),
    );
  }
}
