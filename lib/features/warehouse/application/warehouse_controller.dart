import 'package:flutter/foundation.dart';
import 'package:fmcg/features/warehouse/data/demo_warehouse_data.dart';
import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

class WarehouseController extends ChangeNotifier {
  bool isAuthenticated = false;
  int currentTab = 0;

  final Map<String, StockLabel> labels = DemoWarehouseData.labels();
  final List<PickingList> pickings = DemoWarehouseData.pickings().toList();
  final List<FscmNotification> notifications = DemoWarehouseData.notifications()
      .toList();
  final List<GoodsReceipt> receipts = [];

  int _nextLabelNumber = 204;
  int _nextReceiptNumber = 2;

  int get unreadCount => notifications.where((item) => !item.isRead).length;
  int get waitingCount =>
      pickings.where((item) => item.status == PickingStatus.notStarted).length;
  int get pickingCount =>
      pickings.where((item) => item.status == PickingStatus.inProgress).length;
  int get shippedCount =>
      pickings.where((item) => item.status == PickingStatus.shipped).length;
  int get expiredCount => labels.values
      .where((item) => item.status == StockLabelStatus.expired)
      .length;

  void login() {
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    currentTab = 0;
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  PickingList? pickingById(String id) {
    for (final picking in pickings) {
      if (picking.id == id) return picking;
    }
    return null;
  }

  StockLabel? labelById(String id) => labels[id];

  SourceScanResult validateSourceLabel({
    required String pickingId,
    required int lineIndex,
    required String labelId,
  }) {
    final picking = pickingById(pickingId);
    final label = labels[labelId];
    if (picking == null || label == null) return SourceScanResult.unknown;
    final line = picking.lines[lineIndex];
    if (label.batchCode != line.batchCode) return SourceScanResult.wrongBatch;
    if (label.status != StockLabelStatus.inStock || label.quantity == 0) {
      return SourceScanResult.unavailable;
    }
    return SourceScanResult.matched;
  }

  PickResult? confirmPick({
    required String pickingId,
    required int lineIndex,
    required String sourceLabelId,
    required int quantity,
  }) {
    if (validateSourceLabel(
          pickingId: pickingId,
          lineIndex: lineIndex,
          labelId: sourceLabelId,
        ) !=
        SourceScanResult.matched) {
      return null;
    }
    final pickingIndex = pickings.indexWhere((item) => item.id == pickingId);
    final picking = pickings[pickingIndex];
    final line = picking.lines[lineIndex];
    final source = labels[sourceLabelId]!;
    final remainingNeed = line.requiredQuantity - line.pickedQuantity;
    if (quantity <= 0 ||
        quantity > remainingNeed ||
        quantity > source.quantity) {
      return null;
    }

    final wasSplit = quantity < source.quantity;
    final outputId = wasSplit
        ? 'TEM-${(_nextLabelNumber++).toString().padLeft(6, '0')}'
        : source.id;
    final event = LabelHistoryEntry(
      time: '09:08 27/09',
      description: wasSplit
          ? 'Tách $outputId cho $pickingId'
          : 'Lấy nguyên tem cho $pickingId',
      quantityChange: -quantity,
    );

    if (wasSplit) {
      labels[source.id] = source.copyWith(
        quantity: source.quantity - quantity,
        childIds: [...source.childIds, outputId],
        history: [...source.history, event],
      );
      labels[outputId] = StockLabel(
        id: outputId,
        sku: source.sku,
        batchCode: source.batchCode,
        expiryDate: source.expiryDate,
        quantity: quantity,
        status: StockLabelStatus.picked,
        location: 'Chờ xuất',
        manufacturerLot: source.manufacturerLot,
        parentId: source.id,
        pickingId: pickingId,
        history: [
          LabelHistoryEntry(
            time: '09:08 27/09',
            description: 'Tách từ ${source.id} cho $pickingId',
            quantityChange: quantity,
          ),
        ],
      );
    } else {
      labels[source.id] = source.copyWith(
        status: StockLabelStatus.picked,
        location: 'Chờ xuất',
        pickingId: pickingId,
        history: [...source.history, event],
      );
    }

    final updatedLines = [...picking.lines];
    updatedLines[lineIndex] = line.copyWith(
      pickedQuantity: line.pickedQuantity + quantity,
      outputLabelId: outputId,
      wasSplit: wasSplit,
    );
    pickings[pickingIndex] = picking.copyWith(
      status: PickingStatus.inProgress,
      lines: updatedLines,
    );
    notifyListeners();
    return PickResult(
      outputLabelId: outputId,
      sourceLabelId: source.id,
      wasSplit: wasSplit,
      outputQuantity: quantity,
      remainingQuantity: source.quantity - quantity,
    );
  }

  bool dispatch(String pickingId) {
    final index = pickings.indexWhere((item) => item.id == pickingId);
    if (index < 0 || !pickings[index].canDispatch) return false;
    final picking = pickings[index];
    for (final line in picking.lines) {
      final outputId = line.outputLabelId;
      if (outputId == null) continue;
      final label = labels[outputId];
      if (label == null) continue;
      labels[outputId] = label.copyWith(
        status: StockLabelStatus.inTransit,
        location: 'Đang vận chuyển',
        history: [
          ...label.history,
          LabelHistoryEntry(
            time: '09:15 27/09',
            description: 'Xác nhận xuất $pickingId',
          ),
        ],
      );
    }
    pickings[index] = picking.copyWith(
      status: PickingStatus.shipped,
      shippedAt: '09:15 27/09',
    );
    notifyListeners();
    return true;
  }

  GoodsReceipt? receiveStock({
    required String supplierDocument,
    required String sku,
    required String expiryDate,
    required int quantity,
    required int labelCount,
    String? manufacturerLot,
  }) {
    if (supplierDocument.trim().isEmpty ||
        !DemoWarehouseData.productNames.containsKey(sku) ||
        expiryDate.trim().isEmpty ||
        quantity <= 0 ||
        labelCount <= 0 ||
        labelCount > quantity) {
      return null;
    }
    final compactExpiry = expiryDate.replaceAll('/', '');
    final batchCode = '${DemoWarehouseData.warehouseCode}-$sku-$compactExpiry';
    final baseQuantity = quantity ~/ labelCount;
    final remainder = quantity % labelCount;
    final labelIds = <String>[];
    for (var index = 0; index < labelCount; index++) {
      final labelQuantity = baseQuantity + (index < remainder ? 1 : 0);
      final id = 'TEM-${(_nextLabelNumber + 6).toString().padLeft(6, '0')}';
      _nextLabelNumber++;
      labelIds.add(id);
      labels[id] = StockLabel(
        id: id,
        sku: sku,
        batchCode: batchCode,
        expiryDate: expiryDate,
        quantity: labelQuantity,
        status: StockLabelStatus.inStock,
        location: 'Kệ E-0${index + 1}',
        manufacturerLot: manufacturerLot,
        history: [
          LabelHistoryEntry(
            time: '09:20 27/09',
            description: 'Nhập kho từ $supplierDocument',
            quantityChange: labelQuantity,
          ),
        ],
      );
    }
    final receipt = GoodsReceipt(
      id: 'PN-0927-${(_nextReceiptNumber++).toString().padLeft(2, '0')}',
      supplierDocument: supplierDocument,
      batchCode: batchCode,
      sku: sku,
      quantity: quantity,
      labelIds: labelIds,
    );
    receipts.insert(0, receipt);
    notifyListeners();
    return receipt;
  }

  void markNotificationRead(int id) {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    notifications[index] = notifications[index].markRead();
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (var index = 0; index < notifications.length; index++) {
      notifications[index] = notifications[index].markRead();
    }
    notifyListeners();
  }
}
