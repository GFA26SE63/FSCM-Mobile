enum PickingStatus { notStarted, inProgress, shipped }

enum StockLabelStatus { inStock, picked, inTransit, expired }

enum SourceScanResult { matched, wrongBatch, unavailable, unknown }

class LabelHistoryEntry {
  const LabelHistoryEntry({
    required this.time,
    required this.description,
    this.quantityChange,
  });

  final String time;
  final String description;
  final int? quantityChange;
}

class StockLabel {
  const StockLabel({
    required this.id,
    required this.sku,
    required this.batchCode,
    required this.expiryDate,
    required this.quantity,
    required this.status,
    required this.location,
    this.manufacturerLot,
    this.parentId,
    this.pickingId,
    this.childIds = const [],
    this.history = const [],
  });

  final String id;
  final String sku;
  final String batchCode;
  final String expiryDate;
  final int quantity;
  final StockLabelStatus status;
  final String location;
  final String? manufacturerLot;
  final String? parentId;
  final String? pickingId;
  final List<String> childIds;
  final List<LabelHistoryEntry> history;

  StockLabel copyWith({
    int? quantity,
    StockLabelStatus? status,
    String? location,
    String? pickingId,
    List<String>? childIds,
    List<LabelHistoryEntry>? history,
  }) {
    return StockLabel(
      id: id,
      sku: sku,
      batchCode: batchCode,
      expiryDate: expiryDate,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      location: location ?? this.location,
      manufacturerLot: manufacturerLot,
      parentId: parentId,
      pickingId: pickingId ?? this.pickingId,
      childIds: childIds ?? this.childIds,
      history: history ?? this.history,
    );
  }
}

class PickingLine {
  const PickingLine({
    required this.sku,
    required this.productName,
    required this.batchCode,
    required this.expiryDate,
    required this.location,
    required this.requiredQuantity,
    required this.suggestedLabelId,
    this.pickedQuantity = 0,
    this.outputLabelId,
    this.wasSplit = false,
  });

  final String sku;
  final String productName;
  final String batchCode;
  final String expiryDate;
  final String location;
  final int requiredQuantity;
  final String suggestedLabelId;
  final int pickedQuantity;
  final String? outputLabelId;
  final bool wasSplit;

  bool get isComplete => pickedQuantity >= requiredQuantity;

  PickingLine copyWith({
    int? pickedQuantity,
    String? outputLabelId,
    bool? wasSplit,
  }) {
    return PickingLine(
      sku: sku,
      productName: productName,
      batchCode: batchCode,
      expiryDate: expiryDate,
      location: location,
      requiredQuantity: requiredQuantity,
      suggestedLabelId: suggestedLabelId,
      pickedQuantity: pickedQuantity ?? this.pickedQuantity,
      outputLabelId: outputLabelId ?? this.outputLabelId,
      wasSplit: wasSplit ?? this.wasSplit,
    );
  }
}

class PickingList {
  const PickingList({
    required this.id,
    required this.orderId,
    required this.retailerName,
    required this.retailerId,
    required this.status,
    required this.approvedAt,
    required this.siblingSummary,
    required this.lines,
    this.shippedAt,
  });

  final String id;
  final String orderId;
  final String retailerName;
  final String retailerId;
  final PickingStatus status;
  final String approvedAt;
  final String siblingSummary;
  final List<PickingLine> lines;
  final String? shippedAt;

  int get totalQuantity =>
      lines.fold(0, (sum, line) => sum + line.requiredQuantity);
  int get completedLines => lines.where((line) => line.isComplete).length;
  bool get canDispatch =>
      lines.isNotEmpty && lines.every((line) => line.isComplete);

  PickingList copyWith({
    PickingStatus? status,
    List<PickingLine>? lines,
    String? shippedAt,
  }) {
    return PickingList(
      id: id,
      orderId: orderId,
      retailerName: retailerName,
      retailerId: retailerId,
      status: status ?? this.status,
      approvedAt: approvedAt,
      siblingSummary: siblingSummary,
      lines: lines ?? this.lines,
      shippedAt: shippedAt ?? this.shippedAt,
    );
  }
}

class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.supplierDocument,
    required this.batchCode,
    required this.sku,
    required this.quantity,
    required this.labelIds,
  });

  final String id;
  final String supplierDocument;
  final String batchCode;
  final String sku;
  final int quantity;
  final List<String> labelIds;
}

class PickResult {
  const PickResult({
    required this.outputLabelId,
    required this.sourceLabelId,
    required this.wasSplit,
    required this.outputQuantity,
    required this.remainingQuantity,
  });

  final String outputLabelId;
  final String sourceLabelId;
  final bool wasSplit;
  final int outputQuantity;
  final int remainingQuantity;
}
