import 'package:fmcg/features/retailer/domain/retailer_models.dart';
import 'package:fmcg/shared/domain/fscm_models.dart';

abstract final class DemoRetailerData {
  static const retailer = Retailer(
    id: '10004127',
    name: 'Tạp hóa Minh Châu',
    address: '12 Lê Văn Khương, P. Thới An, Q.12',
    area: 'Quận 12',
    tier: 'Vàng',
    points: 412,
    creditTermDays: 14,
  );

  static const yogurt = Product(
    sku: 'SKU001',
    name: 'Sữa chua có đường 100g',
    pack: 'Thùng 48 hộp',
    category: 'Sữa chua',
    price: 250000,
    stock: 0,
  );
  static const yogurtDrink = Product(
    sku: 'SKU002',
    name: 'Sữa chua uống men sống 65ml',
    pack: 'Thùng 50 chai',
    category: 'Sữa chua',
    price: 210000,
    stock: 0,
  );
  static const milk = Product(
    sku: 'SKU003',
    name: 'Sữa tươi tiệt trùng ít đường 180ml',
    pack: 'Thùng 48 hộp',
    category: 'Sữa tươi',
    price: 320000,
    stock: 0,
  );
  static const freshMilk = Product(
    sku: 'SKU004',
    name: 'Sữa tươi thanh trùng 950ml',
    pack: 'Thùng 12 chai',
    category: 'Sữa tươi',
    price: 360000,
    stock: 0,
  );
  static const bread = Product(
    sku: 'SKU005',
    name: 'Bánh mì sandwich lát 400g',
    pack: 'Thùng 20 gói',
    category: 'Bánh tươi',
    price: 300000,
    stock: 0,
  );

  static List<SalesOrder> orders() => [
    const SalesOrder(
      id: 'DH-1030',
      retailer: retailer,
      lines: [
        OrderLine(product: yogurt, quantity: 60, discountPercent: 5),
        OrderLine(product: milk, quantity: 30),
      ],
      status: SalesOrderStatus.pendingApproval,
      createdAt: '10:12 27/09',
      payment: PaymentInfo(method: PaymentMethod.cod),
    ),
    const SalesOrder(
      id: 'DH-1021',
      retailer: retailer,
      lines: [
        OrderLine(
          product: yogurt,
          quantity: 60,
          discountPercent: 5,
          batches: [
            BatchAllocation(
              batchCode: 'WH-TA-SKU001-18102026',
              quantity: 40,
              expiryDate: '18/10/2026',
              warehouse: 'Kho Thới An',
              labelCode: 'TEM-000187',
            ),
            BatchAllocation(
              batchCode: 'WH-TD-SKU001-18102026',
              quantity: 20,
              expiryDate: '18/10/2026',
              warehouse: 'Kho Thủ Đức',
              labelCode: 'TEM-000192',
            ),
          ],
        ),
        OrderLine(
          product: milk,
          quantity: 30,
          batches: [
            BatchAllocation(
              batchCode: 'WH-GV-SKU003-14102026',
              quantity: 20,
              expiryDate: '14/10/2026',
              warehouse: 'Kho Gò Vấp',
              labelCode: 'TEM-000195',
            ),
            BatchAllocation(
              batchCode: 'WH-TA-SKU003-24102026',
              quantity: 10,
              expiryDate: '24/10/2026',
              warehouse: 'Kho Thới An',
              labelCode: 'TEM-000188',
            ),
          ],
        ),
      ],
      status: SalesOrderStatus.delivering,
      createdAt: '14:20 26/09',
      payment: PaymentInfo(method: PaymentMethod.cod),
      delivery: DeliveryInfo(
        vehiclePlate: '51C-482.17',
        driverName: 'Trương Văn Lực',
        driverPhone: '0907 118 552',
        departedAt: '09:15 27/09',
      ),
    ),
    const SalesOrder(
      id: 'DH-1018',
      retailer: retailer,
      lines: [OrderLine(product: freshMilk, quantity: 90)],
      status: SalesOrderStatus.rejected,
      createdAt: '16:45 23/09',
      rejectionReason: 'Không đủ hàng khả dụng cho SKU004.',
    ),
    const SalesOrder(
      id: 'DH-1015',
      retailer: retailer,
      lines: [
        OrderLine(product: yogurt, quantity: 45),
        OrderLine(product: bread, quantity: 10),
      ],
      status: SalesOrderStatus.delivered,
      createdAt: '10:40 25/09',
      payment: PaymentInfo(
        method: PaymentMethod.cod,
        isPaid: true,
        paidAt: '26/09',
      ),
    ),
    const SalesOrder(
      id: 'DH-0994',
      retailer: retailer,
      lines: [OrderLine(product: milk, quantity: 25)],
      status: SalesOrderStatus.delivered,
      createdAt: '08:50 18/09',
      payment: PaymentInfo(
        method: PaymentMethod.credit,
        paidAmount: 3000000,
        dueDate: '02/10/2026',
      ),
    ),
    const SalesOrder(
      id: 'DH-1012',
      retailer: retailer,
      lines: [
        OrderLine(product: yogurtDrink, quantity: 40, discountPercent: 4),
        OrderLine(product: bread, quantity: 15),
      ],
      status: SalesOrderStatus.delivered,
      createdAt: '09:10 14/09',
      payment: PaymentInfo(
        method: PaymentMethod.bankTransfer,
        isPaid: true,
        paidAt: '14/09',
      ),
    ),
  ];

  static List<FscmNotification> notifications() => const [
    FscmNotification(
      id: 201,
      message: 'Đơn DH-1021 đang được giao. Chuẩn bị quét QR khi nhận hàng.',
      time: '09:15 27/09',
      orderId: 'DH-1021',
    ),
    FscmNotification(
      id: 202,
      message: 'Đơn DH-1018 bị từ chối vì không đủ hàng khả dụng.',
      time: '16:45 23/09',
      orderId: 'DH-1018',
      isRead: true,
    ),
    FscmNotification(
      id: 203,
      message: 'Đơn DH-1012 đã giao thành công.',
      time: '15:20 15/09',
      orderId: 'DH-1012',
      isRead: true,
    ),
  ];

  static List<LoyaltyTransaction> loyaltyHistory() => const [
    LoyaltyTransaction(
      date: '27/09',
      description: 'DH-1021 · đang giao',
      points: 0,
      isPending: true,
    ),
    LoyaltyTransaction(
      date: '25/09',
      description: 'DH-1015 · đã giao, đã thanh toán',
      points: 142,
    ),
    LoyaltyTransaction(
      date: '18/09',
      description: 'DH-0994 · chưa thanh toán đủ',
      points: 0,
      isPending: true,
    ),
    LoyaltyTransaction(
      date: '14/09',
      description: 'DH-1012 · đã giao, đã thanh toán',
      points: 125,
    ),
    LoyaltyTransaction(
      date: '10/09',
      description: 'Đổi điểm trừ tiền đơn hàng',
      points: -50,
    ),
  ];
}
