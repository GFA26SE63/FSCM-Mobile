import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_presenters.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_scope.dart';
import 'package:fmcg/features/warehouse/presentation/widgets/picking_card.dart';
import 'package:fmcg/shared/widgets/inventory_widgets.dart';

class WarehousePickingsScreen extends StatefulWidget {
  const WarehousePickingsScreen({super.key});

  @override
  State<WarehousePickingsScreen> createState() =>
      _WarehousePickingsScreenState();
}

class _WarehousePickingsScreenState extends State<WarehousePickingsScreen> {
  PickingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final items = controller.pickings
        .where((item) => _filter == null || item.status == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Picking list')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              ...PickingStatus.values.map(
                (status) => ChoiceChip(
                  label: Text(pickingStatusLabel(status)),
                  selected: _filter == status,
                  onSelected: (_) => setState(() => _filter = status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (picking) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WarehousePickingCard(
                picking: picking,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WarehousePickingDetailScreen(pickingId: picking.id),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WarehousePickingDetailScreen extends StatelessWidget {
  const WarehousePickingDetailScreen({super.key, required this.pickingId});

  final String pickingId;

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final picking = controller.pickingById(pickingId);
    if (picking == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy picking.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(picking.id),
            Text(
              'Đơn ${picking.orderId} · ${picking.retailerName}',
              style: const TextStyle(
                color: FscmColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: StatusPill(
                label: pickingStatusLabel(picking.status),
                color: pickingStatusColor(picking.status),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          ProgressSummaryCard(
            label: 'Tiến độ dòng hàng',
            completed: picking.completedLines,
            total: picking.lines.length,
            note: picking.siblingSummary,
          ),
          const SizedBox(height: 12),
          ...picking.lines.indexed.map((entry) {
            final index = entry.$1;
            final line = entry.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FscmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${line.productName}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusPill(
                          label: line.isComplete ? 'Đã lấy' : 'Chờ lấy',
                          color: line.isComplete
                              ? const Color(0xFF15703A)
                              : FscmColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InfoRow(label: 'Batch', value: line.batchCode),
                    InfoRow(label: 'HSD', value: line.expiryDate),
                    InfoRow(label: 'Vị trí', value: 'Kệ ${line.location}'),
                    InfoRow(
                      label: 'Cần lấy',
                      value: '${line.requiredQuantity} thùng',
                    ),
                    InfoRow(label: 'Tem gợi ý', value: line.suggestedLabelId),
                    if (line.isComplete) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F4EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${line.outputLabelId} · ${line.pickedQuantity} thùng${line.wasSplit ? ' · tem con đã tách' : ' · lấy nguyên tem'}',
                          style: const TextStyle(
                            color: Color(0xFF14532D),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: Key('scanSourceButton-$index'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WarehouseSourceScanScreen(
                              pickingId: picking.id,
                              lineIndex: index,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Quét tem nguồn'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (picking.status == PickingStatus.shipped)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFE1F1EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Đã xuất lúc ${picking.shippedAt}. Các tem đang ở trạng thái Đang vận chuyển.',
                style: const TextStyle(color: FscmColors.primary, height: 1.4),
              ),
            ),
        ],
      ),
      bottomSheet: picking.status == PickingStatus.shipped
          ? null
          : BottomActionBar(
              child: ElevatedButton(
                key: const Key('warehouseDispatchButton'),
                onPressed: picking.canDispatch
                    ? () {
                        controller.dispatch(picking.id);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WarehouseDispatchSuccessScreen(
                              pickingId: picking.id,
                            ),
                          ),
                        );
                      }
                    : null,
                child: Text(
                  picking.canDispatch
                      ? 'Xác nhận đã xuất'
                      : 'Lấy đủ các dòng để xác nhận xuất',
                ),
              ),
            ),
    );
  }
}

class WarehouseSourceScanScreen extends StatelessWidget {
  const WarehouseSourceScanScreen({
    super.key,
    required this.pickingId,
    required this.lineIndex,
  });

  final String pickingId;
  final int lineIndex;

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final picking = controller.pickingById(pickingId)!;
    final line = picking.lines[lineIndex];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quét tem nguồn'),
            Text(
              '$pickingId · dòng ${lineIndex + 1} · cần ${line.requiredQuantity} thùng',
              style: const TextStyle(
                color: FscmColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ScanFrame(
            height: 230,
            message: 'Đưa tem QR trên pallet vào khung.',
          ),
          const SizedBox(height: 14),
          FscmCard(
            child: Column(
              children: [
                InfoRow(label: 'SKU', value: line.sku),
                InfoRow(label: 'Batch cần lấy', value: line.batchCode),
                InfoRow(label: 'Vị trí', value: 'Kệ ${line.location}'),
                InfoRow(label: 'Tem gợi ý', value: line.suggestedLabelId),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            key: const Key('scanCorrectSourceButton'),
            onPressed: () => _scan(context, line.suggestedLabelId),
            icon: const Icon(Icons.qr_code_scanner),
            label: Text('Quét ${line.suggestedLabelId} (đúng batch)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('scanWrongSourceButton'),
            onPressed: () => _scan(context, 'TEM-000142'),
            icon: const Icon(Icons.error_outline),
            label: const Text('Quét nhầm TEM-000142'),
          ),
        ],
      ),
    );
  }

  void _scan(BuildContext context, String labelId) {
    final controller = WarehouseScope.of(context, listen: false);
    final result = controller.validateSourceLabel(
      pickingId: pickingId,
      lineIndex: lineIndex,
      labelId: labelId,
    );
    if (result == SourceScanResult.matched) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WarehouseQuantityScreen(
            pickingId: pickingId,
            lineIndex: lineIndex,
            sourceLabelId: labelId,
          ),
        ),
      );
      return;
    }
    final message = switch (result) {
      SourceScanResult.wrongBatch =>
        'Sai tem: label này không thuộc batch FEFO của dòng hàng.',
      SourceScanResult.unavailable => 'Tem không còn ở trạng thái có thể lấy.',
      SourceScanResult.unknown => 'Không tìm thấy tem trong kho.',
      SourceScanResult.matched => '',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class WarehouseQuantityScreen extends StatefulWidget {
  const WarehouseQuantityScreen({
    super.key,
    required this.pickingId,
    required this.lineIndex,
    required this.sourceLabelId,
  });

  final String pickingId;
  final int lineIndex;
  final String sourceLabelId;

  @override
  State<WarehouseQuantityScreen> createState() =>
      _WarehouseQuantityScreenState();
}

class _WarehouseQuantityScreenState extends State<WarehouseQuantityScreen> {
  int? _quantity;

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final picking = controller.pickingById(widget.pickingId)!;
    final line = picking.lines[widget.lineIndex];
    final source = controller.labelById(widget.sourceLabelId)!;
    final maximum =
        (line.requiredQuantity - line.pickedQuantity) < source.quantity
        ? line.requiredQuantity - line.pickedQuantity
        : source.quantity;
    _quantity ??= maximum;
    final willSplit = _quantity! < source.quantity;
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận số lượng')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F4EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tem ${source.id} đúng batch ${source.batchCode}, đang ở ${source.location}.',
              style: const TextStyle(color: Color(0xFF14532D), height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          FscmCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Tem nguồn có',
                  value: '${source.quantity} thùng',
                ),
                InfoRow(label: 'Dòng cần lấy', value: '$maximum thùng'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Số thùng thực lấy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    QuantityStepper(
                      value: _quantity!,
                      maximum: maximum,
                      onChanged: (value) => setState(() => _quantity = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FscmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kết quả sau khi xác nhận',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  willSplit
                      ? 'Tạo tem con mới cho $_quantity thùng. Tem gốc ${source.id} giữ nguyên mã và còn ${source.quantity - _quantity!} thùng.'
                      : 'Lấy nguyên tem ${source.id}; không cần tạo hoặc in tem mới.',
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: BottomActionBar(
        child: ElevatedButton(
          key: const Key('confirmPickQuantityButton'),
          onPressed: () {
            final result = controller.confirmPick(
              pickingId: widget.pickingId,
              lineIndex: widget.lineIndex,
              sourceLabelId: widget.sourceLabelId,
              quantity: _quantity!,
            );
            if (result == null) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => WarehouseLabelResultScreen(
                  pickingId: widget.pickingId,
                  lineIndex: widget.lineIndex,
                  result: result,
                ),
              ),
            );
          },
          child: Text(
            willSplit ? 'Tách & in tem con' : 'Xác nhận lấy nguyên tem',
          ),
        ),
      ),
    );
  }
}

class WarehouseLabelResultScreen extends StatelessWidget {
  const WarehouseLabelResultScreen({
    super.key,
    required this.pickingId,
    required this.lineIndex,
    required this.result,
  });

  final String pickingId;
  final int lineIndex;
  final PickResult result;

  @override
  Widget build(BuildContext context) {
    final controller = WarehouseScope.of(context);
    final output = controller.labelById(result.outputLabelId)!;
    final source = controller.labelById(result.sourceLabelId)!;
    final picking = controller.pickingById(pickingId)!;
    final nextLine = picking.lines.indexWhere((line) => !line.isComplete);
    return Scaffold(
      appBar: AppBar(
        title: Text(result.wasSplit ? 'Tem con vừa tạo' : 'Tem đi theo đơn'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InventoryLabelCard(
            labelId: output.id,
            sku: output.sku,
            quantity: output.quantity,
            batchCode: output.batchCode,
            expiryDate: output.expiryDate,
            location: output.location,
            destination: '$pickingId · ${picking.retailerName}',
            status: stockStatusLabel(output.status),
            statusColor: stockStatusColor(output.status),
          ),
          const SizedBox(height: 12),
          FscmCard(
            child: Text(
              result.wasSplit
                  ? 'Dán tem con lên ${result.outputQuantity} thùng vừa tách. Tem gốc giữ nguyên mã và số lượng hệ thống còn ${result.remainingQuantity} thùng.'
                  : 'Lấy nguyên tem nên không cần in tem mới. Tem hiện có đi theo đơn.',
              style: const TextStyle(height: 1.5),
            ),
          ),
          if (result.wasSplit) ...[
            const SizedBox(height: 18),
            const SectionTitle('Tem gốc còn lại trên kệ'),
            const SizedBox(height: 8),
            InventoryLabelCard(
              labelId: source.id,
              sku: source.sku,
              quantity: source.quantity,
              batchCode: source.batchCode,
              expiryDate: source.expiryDate,
              location: source.location,
              status: stockStatusLabel(source.status),
              statusColor: stockStatusColor(source.status),
            ),
          ],
          const SizedBox(height: 18),
          if (result.wasSplit)
            ElevatedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã in tem ${output.id}.')),
              ),
              icon: const Icon(Icons.print_outlined),
              label: const Text('In tem con'),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              if (nextLine >= 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => WarehouseSourceScanScreen(
                      pickingId: pickingId,
                      lineIndex: nextLine,
                    ),
                  ),
                );
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              nextLine >= 0
                  ? 'Tiếp tục dòng ${nextLine + 1}'
                  : 'Về picking list để xác nhận xuất',
            ),
          ),
        ],
      ),
    );
  }
}

class WarehouseDispatchSuccessScreen extends StatelessWidget {
  const WarehouseDispatchSuccessScreen({super.key, required this.pickingId});

  final String pickingId;

  @override
  Widget build(BuildContext context) {
    final picking = WarehouseScope.of(context).pickingById(pickingId)!;
    return Scaffold(
      body: SuccessPanel(
        title: 'Đã xuất $pickingId',
        message:
            'Tồn thực tế đã trừ và hàng giữ chỗ được giải phóng. ${picking.lines.length} tem chuyển sang Đang vận chuyển để retailer quét khi nhận.',
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Về chi tiết picking'),
          ),
        ],
      ),
    );
  }
}
