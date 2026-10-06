import 'package:fmcg/features/sales/domain/sales_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

abstract final class DemoSalesData {
  static const products = <Product>[
    Product(
      sku: 'SKU001',
      name: 'Sữa chua có đường 100g',
      pack: 'Thùng 48 hộp',
      category: 'Sữa chua',
      price: 250000,
      stock: 220,
    ),
    Product(
      sku: 'SKU002',
      name: 'Sữa chua uống men sống 65ml',
      pack: 'Thùng 50 chai',
      category: 'Sữa chua',
      price: 210000,
      stock: 300,
    ),
    Product(
      sku: 'SKU003',
      name: 'Sữa tươi tiệt trùng ít đường 180ml',
      pack: 'Thùng 48 hộp',
      category: 'Sữa tươi',
      price: 320000,
      stock: 200,
    ),
    Product(
      sku: 'SKU004',
      name: 'Sữa tươi thanh trùng 950ml',
      pack: 'Thùng 12 chai',
      category: 'Sữa tươi',
      price: 360000,
      stock: 80,
    ),
    Product(
      sku: 'SKU005',
      name: 'Bánh mì sandwich lát 400g',
      pack: 'Thùng 20 gói',
      category: 'Bánh tươi',
      price: 300000,
      stock: 150,
    ),
    Product(
      sku: 'SKU006',
      name: 'Bánh bông lan kem 55g',
      pack: 'Thùng 60 cái',
      category: 'Bánh tươi',
      price: 270000,
      stock: 90,
    ),
    Product(
      sku: 'SKU007',
      name: 'Phô mai que 120g',
      pack: 'Thùng 24 gói',
      category: 'Đồ mát',
      price: 540000,
      stock: 40,
    ),
  ];

  static const retailers = <Retailer>[
    Retailer(
      id: '10004127',
      name: 'Tạp hóa Minh Châu',
      address: '12 Lê Văn Khương, P. Thới An, Q.12',
      area: 'Quận 12',
      tier: 'Vàng',
      points: 412,
      creditTermDays: 14,
    ),
    Retailer(
      id: '10004135',
      name: 'Siêu thị mini Hòa Bình',
      address: '45 Tô Ký, P. Tân Chánh Hiệp, Q.12',
      area: 'Quận 12',
      tier: 'Kim cương',
      points: 742,
      creditTermDays: 30,
    ),
    Retailer(
      id: '10004182',
      name: 'Cửa hàng tiện lợi An Phú',
      address: '88 Nguyễn Ảnh Thủ, P. Hiệp Thành, Q.12',
      area: 'Quận 12',
      tier: 'Vàng',
      points: 341,
      creditTermDays: 14,
    ),
    Retailer(
      id: '10004219',
      name: 'Tạp hóa Thanh Xuân',
      address: '210 Hà Huy Giáp, P. Thạnh Lộc, Q.12',
      area: 'Quận 12',
      tier: 'Bạc',
      points: 272,
      creditTermDays: 7,
    ),
    Retailer(
      id: '10004256',
      name: 'Tạp hóa Ngọc Lan',
      address: '19 Phan Văn Hớn, X. Xuân Thới Thượng, Hóc Môn',
      area: 'Hóc Môn',
      tier: 'Thành viên',
      points: 0,
      creditTermDays: 0,
    ),
    Retailer(
      id: '10004288',
      name: 'Bách hóa Tâm An',
      address: '102 Quang Trung, P.10, Gò Vấp',
      area: 'Gò Vấp',
      tier: 'Thành viên',
      points: 0,
      creditTermDays: 7,
    ),
  ];

  static const promotions = <Promotion>[
    Promotion(
      id: 'KM01',
      name: 'Ưu đãi sữa chua tháng 9',
      validity: '01/09 – 30/09/2026',
      description: 'Giảm 5% SKU001 từ 50 thùng; giảm 4% SKU002 từ 30 thùng.',
    ),
    Promotion(
      id: 'KM02',
      name: 'Combo sữa tươi',
      validity: '15/09 – 15/10/2026',
      description: 'Giảm 3% khi tổng SKU003 và SKU004 đạt 40 thùng.',
    ),
    Promotion(
      id: 'KM03',
      name: 'Xả hàng bánh tươi',
      validity: '20/09 – 05/10/2026',
      description: 'Giảm 8% SKU005 hoặc SKU006 từ 20 thùng.',
    ),
  ];

  static List<SalesOrder> orders() => [
    SalesOrder(
      id: 'DH-1030',
      retailer: retailers[0],
      lines: [
        OrderLine(product: products[0], quantity: 60, discountPercent: 5),
        OrderLine(product: products[2], quantity: 30),
      ],
      status: SalesOrderStatus.pendingApproval,
      createdAt: '10:12 27/09',
    ),
    SalesOrder(
      id: 'DH-1029',
      retailer: retailers[1],
      lines: [OrderLine(product: products[4], quantity: 30)],
      status: SalesOrderStatus.pendingApproval,
      createdAt: '10:20 27/09',
      wasOffline: true,
      syncedAt: '10:31 27/09',
    ),
    SalesOrder(
      id: 'DH-1028',
      retailer: retailers[0],
      lines: [
        OrderLine(product: products[0], quantity: 60, discountPercent: 5),
      ],
      status: SalesOrderStatus.rejected,
      createdAt: '10:17 27/09',
      wasOffline: true,
      syncedAt: '10:30 27/09',
      rejectionReason:
          'Không đủ hàng: đơn khác đã giữ tồn SKU001 trước khi đồng bộ.',
    ),
    SalesOrder(
      id: 'DH-1024',
      retailer: retailers[2],
      lines: [
        OrderLine(product: products[0], quantity: 50, discountPercent: 5),
        OrderLine(product: products[2], quantity: 20),
      ],
      status: SalesOrderStatus.approved,
      createdAt: '08:10 27/09',
    ),
    SalesOrder(
      id: 'DH-1021',
      retailer: retailers[0],
      lines: [
        OrderLine(product: products[0], quantity: 60, discountPercent: 5),
        OrderLine(product: products[2], quantity: 30),
      ],
      status: SalesOrderStatus.delivering,
      createdAt: '14:20 26/09',
    ),
    SalesOrder(
      id: 'DH-1019',
      retailer: retailers[1],
      lines: [
        OrderLine(product: products[2], quantity: 30),
        OrderLine(product: products[3], quantity: 12),
      ],
      status: SalesOrderStatus.delivered,
      createdAt: '10:30 24/09',
    ),
  ];

  static List<FscmNotification> notifications() => const [
    FscmNotification(
      id: 1,
      message: 'Đơn DH-1024 đã được duyệt và chuyển sang chuẩn bị hàng.',
      time: '08:32 27/09',
      orderId: 'DH-1024',
    ),
    FscmNotification(
      id: 2,
      message: 'Đơn DH-1021 đang được giao đến Tạp hóa Minh Châu.',
      time: '09:15 27/09',
      orderId: 'DH-1021',
    ),
    FscmNotification(
      id: 3,
      message: 'Đơn DH-1018 bị từ chối vì không đủ hàng khả dụng.',
      time: '16:45 23/09',
      orderId: 'DH-1018',
      isRead: true,
    ),
  ];

  static List<RetailerLead> leads() => const [
    RetailerLead(
      id: 'KB-0012',
      name: 'Tạp hóa Hải Yến',
      address: '31 Trường Chinh, P. Tân Thới Nhất, Q.12',
      contact: 'Chị Hải Yến',
      phone: '0903 456 789',
      status: RetailerLeadStatus.pending,
      potentialClass: 'B',
    ),
    RetailerLead(
      id: 'KB-0011',
      name: 'Tạp hóa Ngọc Lan',
      address: '19 Phan Văn Hớn, Hóc Môn',
      contact: 'Anh Tuấn',
      phone: '0918 222 105',
      status: RetailerLeadStatus.approved,
      potentialClass: 'C',
      retailerCode: '10004256',
    ),
    RetailerLead(
      id: 'KB-0009',
      name: 'Quán nước Út Mười',
      address: '90 Nguyễn Ảnh Thủ, P. Hiệp Thành, Q.12',
      contact: 'Chú Mười',
      phone: '0908 771 002',
      status: RetailerLeadStatus.rejected,
      potentialClass: 'C',
      reason: 'Trùng địa chỉ với điểm bán hiện có.',
    ),
  ];
}
