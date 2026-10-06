import 'package:fmcg/features/warehouse/domain/warehouse_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

abstract final class DemoWarehouseData {
  static const warehouseName = 'Kho Thới An';
  static const warehouseCode = 'WH-TA';
  static const keeperName = 'Đỗ Văn Tâm';

  static const productNames = <String, String>{
    'SKU001': 'Sữa chua có đường 100g',
    'SKU002': 'Sữa chua uống men sống 65ml',
    'SKU003': 'Sữa tươi tiệt trùng ít đường 180ml',
    'SKU005': 'Bánh mì sandwich lát 400g',
    'SKU006': 'Bánh bông lan kem 55g',
    'SKU007': 'Phô mai que 120g',
  };

  static Map<String, StockLabel> labels() => {
    'TEM-000118': const StockLabel(
      id: 'TEM-000118',
      sku: 'SKU001',
      batchCode: 'WH-TA-SKU001-18102026',
      expiryDate: '18/10/2026',
      quantity: 40,
      status: StockLabelStatus.inStock,
      location: 'Kệ A-03',
      childIds: ['TEM-000160', 'TEM-000187'],
      history: [
        LabelHistoryEntry(
          time: '07:30 15/09',
          description: 'Nhập kho PN-0915-01',
          quantityChange: 100,
        ),
        LabelHistoryEntry(
          time: '08:20 27/09',
          description: 'Tách TEM-000187 cho DH-1021A',
          quantityChange: -40,
        ),
      ],
    ),
    'TEM-000131': const StockLabel(
      id: 'TEM-000131',
      sku: 'SKU003',
      batchCode: 'WH-TA-SKU003-24102026',
      expiryDate: '24/10/2026',
      quantity: 30,
      status: StockLabelStatus.inStock,
      location: 'Kệ B-01',
      childIds: ['TEM-000165', 'TEM-000176', 'TEM-000188'],
      history: [
        LabelHistoryEntry(
          time: '07:45 16/09',
          description: 'Nhập kho PN-0916-01',
          quantityChange: 60,
        ),
        LabelHistoryEntry(
          time: '08:25 27/09',
          description: 'Tách TEM-000188 cho DH-1021A',
          quantityChange: -10,
        ),
      ],
    ),
    'TEM-000142': const StockLabel(
      id: 'TEM-000142',
      sku: 'SKU002',
      batchCode: 'WH-TA-SKU002-20102026',
      expiryDate: '20/10/2026',
      quantity: 100,
      status: StockLabelStatus.inStock,
      location: 'Kệ C-02',
      history: [
        LabelHistoryEntry(
          time: '07:20 27/09',
          description: 'Nhập kho PN-0927-01',
          quantityChange: 100,
        ),
      ],
    ),
    'TEM-000099': const StockLabel(
      id: 'TEM-000099',
      sku: 'SKU001',
      batchCode: 'WH-TA-SKU001-25092026',
      expiryDate: '25/09/2026',
      quantity: 10,
      status: StockLabelStatus.expired,
      location: 'Kệ A-01',
      history: [
        LabelHistoryEntry(
          time: '00:00 25/09',
          description: 'Hệ thống chuyển Hết hạn – chờ lập phiếu hủy',
        ),
      ],
    ),
    'TEM-000187': const StockLabel(
      id: 'TEM-000187',
      sku: 'SKU001',
      batchCode: 'WH-TA-SKU001-18102026',
      expiryDate: '18/10/2026',
      quantity: 40,
      status: StockLabelStatus.inTransit,
      location: 'Đang vận chuyển',
      parentId: 'TEM-000118',
      pickingId: 'DH-1021A',
      history: [
        LabelHistoryEntry(
          time: '08:40 27/09',
          description: 'Xác nhận xuất DH-1021A',
        ),
      ],
    ),
  };

  static List<PickingList> pickings() => [
    const PickingList(
      id: 'DH-1024A',
      orderId: 'DH-1024',
      retailerName: 'Cửa hàng tiện lợi An Phú',
      retailerId: '10004182',
      status: PickingStatus.notStarted,
      approvedAt: '08:32 27/09',
      siblingSummary:
          'DH-1024B · Kho Tân Chánh Hiệp · 10 thùng SKU001 · Chưa pick',
      lines: [
        PickingLine(
          sku: 'SKU001',
          productName: 'Sữa chua có đường 100g',
          batchCode: 'WH-TA-SKU001-18102026',
          expiryDate: '18/10/2026',
          location: 'A-03',
          requiredQuantity: 40,
          suggestedLabelId: 'TEM-000118',
        ),
        PickingLine(
          sku: 'SKU003',
          productName: 'Sữa tươi tiệt trùng ít đường 180ml',
          batchCode: 'WH-TA-SKU003-24102026',
          expiryDate: '24/10/2026',
          location: 'B-01',
          requiredQuantity: 20,
          suggestedLabelId: 'TEM-000131',
        ),
      ],
    ),
    const PickingList(
      id: 'DH-1021A',
      orderId: 'DH-1021',
      retailerName: 'Tạp hóa Minh Châu',
      retailerId: '10004127',
      status: PickingStatus.shipped,
      approvedAt: '16:05 26/09',
      shippedAt: '08:40 27/09',
      siblingSummary: 'DH-1021B (Kho Thủ Đức), DH-1021C (Kho Gò Vấp) · Đã xuất',
      lines: [
        PickingLine(
          sku: 'SKU001',
          productName: 'Sữa chua có đường 100g',
          batchCode: 'WH-TA-SKU001-18102026',
          expiryDate: '18/10/2026',
          location: 'A-03',
          requiredQuantity: 40,
          suggestedLabelId: 'TEM-000118',
          pickedQuantity: 40,
          outputLabelId: 'TEM-000187',
          wasSplit: true,
        ),
      ],
    ),
  ];

  static List<FscmNotification> notifications() => const [
    FscmNotification(
      id: 1,
      message:
          'Picking list mới DH-1024A – Operator Lý Thu Trang vừa duyệt đơn.',
      time: '08:32 27/09',
      orderId: 'DH-1024A',
    ),
    FscmNotification(
      id: 2,
      message:
          'Batch WH-TA-SKU001-25092026 (TEM-000099) đã hết hạn – chờ lập phiếu hủy.',
      time: '00:00 25/09',
    ),
    FscmNotification(
      id: 3,
      message: 'Đơn DH-1021 đã được retailer xác nhận nhận hàng.',
      time: '10:32 27/09',
      orderId: 'DH-1021A',
      isRead: true,
    ),
  ];
}
