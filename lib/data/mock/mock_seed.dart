import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/app_notification.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/models/product.dart';
import 'package:fscm_mobile/data/models/promotion.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/retailer.dart';
import 'package:fscm_mobile/data/models/retailer_registration.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/data/models/transfer.dart';
import 'package:fscm_mobile/data/pricing/promotion_calculator.dart';

/// Demo data copied from the approved prototypes (Main.dc.html = Sales app,
/// Retailer.dc.html, Warehouse.dc.html). "Now" is 27/09/2026 10:12.
class MockSeed {
  MockSeed._();

  static DateTime _d(int day, int hour, int minute, [int month = 9]) =>
      DateTime(2026, month, day, hour, minute);

  static void fill(MockStore s) {
    _users(s);
    _catalog(s);
    _orders(s);
    _warehouse(s);
    _finance(s);
    _loyalty(s);
    _performance(s);
    _notifications(s);
    _registrations(s);
  }

  // ------------------------------------------------------------------ users

  static void _users(MockStore s) {
    s.users.addAll(const <MockUser>[
      MockUser(
        id: 'U-SALES-01',
        fullName: 'Nguyễn Văn An',
        phone: '0909123456',
        role: UserRole.sales,
        areaCode: 'Q12',
        areaName: 'Quận 12',
        salesGroup: 'Q12-A',
      ),
      MockUser(
        id: 'U-WK-01',
        fullName: 'Đỗ Văn Tâm',
        phone: '0912440118',
        role: UserRole.warehouseKeeper,
        warehouseCode: 'WH-TA',
        warehouseName: 'Kho Thới An',
      ),
      MockUser(
        id: 'U-RT-01',
        fullName: 'Tạp hóa Minh Châu',
        phone: '0909555127',
        role: UserRole.retailer,
        retailerCode: '10004127',
        retailerName: 'Tạp hóa Minh Châu',
        retailerAddress: '12 Lê Văn Khương, P. Thới An, Q.12',
      ),
    ]);
  }

  // ---------------------------------------------------------------- catalog

  static void _catalog(MockStore s) {
    s.products.addAll(const <Product>[
      Product(
          sku: 'SKU001',
          name: 'Sữa chua có đường 100g',
          pack: 'Thùng 48 hộp',
          category: 'Sữa chua',
          basePrice: 250000,
          shelfLifeDays: 30),
      Product(
          sku: 'SKU002',
          name: 'Sữa chua uống men sống 65ml',
          pack: 'Thùng 50 chai',
          category: 'Sữa chua',
          basePrice: 210000,
          shelfLifeDays: 30),
      Product(
          sku: 'SKU003',
          name: 'Sữa tươi tiệt trùng ít đường 180ml',
          pack: 'Thùng 48 hộp',
          category: 'Sữa tươi',
          basePrice: 320000,
          shelfLifeDays: 120),
      Product(
          sku: 'SKU004',
          name: 'Sữa tươi thanh trùng 950ml',
          pack: 'Thùng 12 chai',
          category: 'Sữa tươi',
          basePrice: 360000,
          shelfLifeDays: 14),
      Product(
          sku: 'SKU005',
          name: 'Bánh mì sandwich lát 400g',
          pack: 'Thùng 20 gói',
          category: 'Bánh tươi',
          basePrice: 300000,
          shelfLifeDays: 10),
      Product(
          sku: 'SKU006',
          name: 'Bánh bông lan kem 55g',
          pack: 'Thùng 60 cái',
          category: 'Bánh tươi',
          basePrice: 270000,
          shelfLifeDays: 15),
      Product(
          sku: 'SKU007',
          name: 'Phô mai que 120g',
          pack: 'Thùng 24 gói',
          category: 'Đồ mát',
          basePrice: 540000,
          shelfLifeDays: 60),
    ]);
    s.retailers.addAll(const <Retailer>[
      Retailer(
          code: '10004127',
          name: 'Tạp hóa Minh Châu',
          address: '12 Lê Văn Khương, P. Thới An, Q.12',
          areaCode: 'Q12',
          areaName: 'Quận 12',
          region: 'Miền Nam',
          creditTerm: 14,
          tier: 'Vàng',
          points: 412,
          phone: '0909 555 127',
          contactName: 'Chị Châu'),
      Retailer(
          code: '10004135',
          name: 'Siêu thị mini Hòa Bình',
          address: '45 Tô Ký, P. Tân Chánh Hiệp, Q.12',
          areaCode: 'Q12',
          areaName: 'Quận 12',
          region: 'Miền Nam',
          creditTerm: 30,
          tier: 'Kim cương',
          points: 392,
          phone: '0908 135 135',
          contactName: 'Anh Bình'),
      Retailer(
          code: '10004182',
          name: 'Cửa hàng tiện lợi An Phú',
          address: '88 Nguyễn Ảnh Thủ, P. Hiệp Thành, Q.12',
          areaCode: 'Q12',
          areaName: 'Quận 12',
          region: 'Miền Nam',
          creditTerm: 14,
          tier: 'Vàng',
          points: 221,
          phone: '0907 182 182',
          contactName: 'Chị Phú'),
      Retailer(
          code: '10004219',
          name: 'Tạp hóa Thanh Xuân',
          address: '210 Hà Huy Giáp, P. Thạnh Lộc, Q.12',
          areaCode: 'Q12',
          areaName: 'Quận 12',
          region: 'Miền Nam',
          creditTerm: 7,
          tier: 'Bạc',
          points: 272,
          phone: '0906 219 219',
          contactName: 'Cô Xuân'),
      Retailer(
          code: '10004256',
          name: 'Tạp hóa Ngọc Lan',
          address: '19 Phan Văn Hớn, X. Xuân Thới Thượng, Hóc Môn',
          areaCode: 'HM',
          areaName: 'Hóc Môn',
          region: 'Miền Nam',
          creditTerm: 0,
          tier: 'Thành viên',
          points: 0,
          phone: '0918 222 105',
          contactName: 'Anh Tuấn'),
      Retailer(
          code: '10004288',
          name: 'Bách hóa Tâm An',
          address: '102 Quang Trung, P. 10, Gò Vấp',
          areaCode: 'GV',
          areaName: 'Gò Vấp',
          region: 'Miền Nam',
          creditTerm: 7,
          tier: 'Thành viên',
          points: 0,
          phone: '0977 310 884',
          contactName: 'Chị Tâm'),
    ]);
    s.promotions.addAll(<Promotion>[
      Promotion(
        id: 'KM-001',
        name: 'Ưu đãi sữa chua tháng 9',
        type: 1,
        validFrom: DateTime(2026, 9, 1),
        validTo: DateTime(2026, 9, 30),
        rules: const <PromoRule>[
          PromoRule(sku: 'SKU001', minQty: 50, pct: 5),
          PromoRule(sku: 'SKU002', minQty: 30, pct: 4),
        ],
      ),
      Promotion(
        id: 'KM-002',
        name: 'Combo sữa tươi',
        type: 2,
        validFrom: DateTime(2026, 9, 15),
        validTo: DateTime(2026, 10, 15),
        retailerCodes: const <String>['10004127', '10004135', '10004182'],
        groupSkus: const <String>['SKU003', 'SKU004'],
        groupMinQty: 40,
        groupPct: 3,
      ),
      Promotion(
        id: 'KM-003',
        name: 'Xả hàng bánh tươi',
        type: 1,
        validFrom: DateTime(2026, 9, 20),
        validTo: DateTime(2026, 10, 5),
        rules: const <PromoRule>[
          PromoRule(sku: 'SKU005', minQty: 20, pct: 8),
          PromoRule(sku: 'SKU006', minQty: 20, pct: 8),
        ],
      ),
      Promotion(
        id: 'KM-004',
        name: 'Khách hàng thân thiết',
        type: 1,
        validFrom: DateTime(2026, 9, 1),
        validTo: DateTime(2026, 12, 31),
        retailerCodes: const <String>['10004135'],
        rules: const <PromoRule>[PromoRule(sku: 'SKU003', minQty: 30, pct: 5)],
      ),
    ]);
    s.stock.addAll(const <String, int>{
      'SKU001': 220,
      'SKU002': 300,
      'SKU003': 200,
      'SKU004': 80,
      'SKU005': 150,
      'SKU006': 90,
      'SKU007': 40,
    });
  }

  // ----------------------------------------------------------------- orders

  static Order _order(
    MockStore s,
    String code,
    String retailerCode,
    List<CartLine> lines,
    OrderStatus status,
    DateTime created, {
    String by = 'Nguyễn Văn An',
    PaymentMethod pay = PaymentMethod.cod,
    int term = 0,
    String reason = '',
    bool paid = false,
    DateTime? paidAt,
    DateTime? due,
    Map<String, List<BatchAllocation>> batches =
        const <String, List<BatchAllocation>>{},
    List<TimelineEntry> timeline = const <TimelineEntry>[],
    bool offline = false,
    String offlineCode = '',
    bool promoChanged = false,
    String changeReason = '',
    int? localFinal,
    DateTime? syncedAt,
    String syncMode = '',
    String plate = '',
    String driver = '',
    String driverPhone = '',
    DateTime? departed,
    List<String> labelCodes = const <String>[],
    int pointsEarned = 0,
    List<String> skipPromos = const <String>[],
  }) {
    final retailer = s.retailer(retailerCode);
    final quote = PromotionCalculator.quote(
      lines: lines,
      retailerCode: retailerCode,
      promotions:
          s.promotions.where((p) => !skipPromos.contains(p.id)).toList(),
      products: s.productMap,
      prices: s.prices,
      now: DateTime(2026, 9, 27),
    );
    return Order(
      code: code,
      retailerCode: retailerCode,
      retailerName: retailer?.name ?? retailerCode,
      status: status,
      createdAt: created,
      createdByName: by,
      payment: pay,
      creditTerm: term,
      rejectReason: reason,
      paid: paid,
      paidAt: paidAt,
      dueDate: due,
      total: quote.total,
      discount: quote.discount,
      lines: quote.lines
          .map((l) => OrderLine(
                sku: l.sku,
                name: l.name,
                qty: l.qty,
                unitPrice: l.unitPrice,
                discount: l.discount,
                discountPct: l.pct,
                promoId: l.promoId,
                promoName: l.promoName,
                batches: batches[l.sku] ?? const <BatchAllocation>[],
              ))
          .toList(),
      isOffline: offline,
      offlineCode: offlineCode,
      promoChanged: promoChanged,
      changeReason: changeReason,
      localFinal: localFinal,
      syncedAt: syncedAt,
      syncMode: syncMode,
      vehiclePlate: plate,
      driverName: driver,
      driverPhone: driverPhone,
      departedAt: departed,
      labelCodes: labelCodes,
      pointsEarned: pointsEarned,
      timeline: timeline,
    );
  }

  static TimelineEntry _t(DateTime t, String label) =>
      TimelineEntry(time: t, label: label);

  static void _orders(MockStore s) {
    s.orders.addAll(<Order>[
      _order(
          s,
          'DH-001030',
          '10004127',
          const <CartLine>[
            CartLine(sku: 'SKU001', qty: 60),
            CartLine(sku: 'SKU003', qty: 30)
          ],
          OrderStatus.pending,
          _d(27, 10, 12),
          timeline: <TimelineEntry>[
            _t(_d(27, 10, 12), 'Tạo đơn (online)'),
            _t(_d(27, 10, 12),
                'Hệ thống tính khuyến mãi, phân bổ kho và batch, tạm giữ hàng'),
            _t(_d(27, 10, 12), 'Chờ duyệt'),
          ]),
      _order(
          s,
          'DH-001029',
          '10004135',
          const <CartLine>[CartLine(sku: 'SKU005', qty: 30)],
          OrderStatus.pending,
          _d(27, 10, 20),
          offline: true,
          offlineCode: 'OFF-M3F7-0002',
          promoChanged: true,
          changeReason:
              'KM-003 đã bị Admin tạm dừng lúc 09:30, sau lần tải dữ liệu gần nhất.',
          localFinal: 8280000,
          skipPromos: const <String>['KM-003'],
          syncedAt: _d(27, 10, 31),
          syncMode: 'Thủ công - bạn bấm đồng bộ (tự động thất bại lúc 10:29)',
          timeline: <TimelineEntry>[
            _t(_d(27, 10, 20),
                'Tạo đơn khi offline - khuyến mãi tạm tính −720.000đ'),
            _t(_d(27, 10, 31),
                'Đồng bộ thủ công - hệ thống tính lại khuyến mãi: KM-003 đã tạm dừng'),
            _t(_d(27, 10, 31),
                'Phân bổ kho và batch, tạm giữ hàng - chờ duyệt'),
          ]),
      _order(
          s,
          'DH-001028',
          '10004127',
          const <CartLine>[CartLine(sku: 'SKU001', qty: 60)],
          OrderStatus.rejected,
          _d(27, 10, 17),
          offline: true,
          offlineCode: 'OFF-M3F7-0001',
          syncedAt: _d(27, 10, 30),
          syncMode: 'Thủ công - bạn bấm đồng bộ (tự động thất bại lúc 10:29)',
          reason:
              'Không đủ hàng - đơn khác đã được xử lý trước (SKU001 cần 60, chỉ còn 15 thùng hợp lệ).',
          timeline: <TimelineEntry>[
            _t(_d(27, 10, 17), 'Tạo đơn khi offline'),
            _t(_d(27, 10, 30),
                'Đồng bộ - đơn DH-000931 và DH-001030 tới trước đã giữ hàng SKU001'),
            _t(_d(27, 10, 30),
                'Hệ thống tự động từ chối - đã báo bạn và retailer'),
          ]),
      _order(
          s,
          'DH-001025',
          '10004219',
          const <CartLine>[
            CartLine(sku: 'SKU002', qty: 40),
            CartLine(sku: 'SKU006', qty: 30)
          ],
          OrderStatus.pending,
          _d(27, 9, 5),
          by: 'Trần Thị Bình',
          timeline: <TimelineEntry>[
            _t(_d(27, 9, 5), 'Trần Thị Bình tạo đơn (online)'),
            _t(_d(27, 9, 5), 'Chờ duyệt'),
          ]),
      _order(
          s,
          'DH-001024',
          '10004182',
          const <CartLine>[
            CartLine(sku: 'SKU001', qty: 50),
            CartLine(sku: 'SKU003', qty: 20)
          ],
          OrderStatus.approved,
          _d(27, 8, 10),
          pay: PaymentMethod.prepaid,
          timeline: <TimelineEntry>[
            _t(_d(27, 8, 10), 'Tạo đơn (online)'),
            _t(_d(27, 8, 32), 'Operator đã duyệt - đã sinh picking list'),
          ]),
      _order(
          s,
          'DH-001021',
          '10004127',
          const <CartLine>[
            CartLine(sku: 'SKU001', qty: 60),
            CartLine(sku: 'SKU003', qty: 30)
          ],
          OrderStatus.delivering,
          _d(26, 14, 20),
          plate: '51C-482.17',
          driver: 'Trương Văn Lực',
          driverPhone: '0907 118 552',
          departed: _d(27, 9, 15),
          labelCodes: const <String>[
            'TEM-000187',
            'TEM-000192',
            'TEM-000195',
            'TEM-000188'
          ],
          batches: <String, List<BatchAllocation>>{
            'SKU001': <BatchAllocation>[
              BatchAllocation(
                  batchCode: 'WH-TA-SKU001-18102026',
                  qty: 40,
                  expiry: DateTime(2026, 10, 18),
                  warehouseName: 'Kho Thới An',
                  labelCode: 'TEM-000187'),
              BatchAllocation(
                  batchCode: 'WH-TD-SKU001-18102026',
                  qty: 20,
                  expiry: DateTime(2026, 10, 18),
                  warehouseName: 'Kho Thủ Đức',
                  labelCode: 'TEM-000192'),
            ],
            'SKU003': <BatchAllocation>[
              BatchAllocation(
                  batchCode: 'WH-GV-SKU003-14102026',
                  qty: 20,
                  expiry: DateTime(2026, 10, 14),
                  warehouseName: 'Kho Gò Vấp',
                  labelCode: 'TEM-000195'),
              BatchAllocation(
                  batchCode: 'WH-TA-SKU003-24102026',
                  qty: 10,
                  expiry: DateTime(2026, 10, 24),
                  warehouseName: 'Kho Thới An',
                  labelCode: 'TEM-000188'),
            ],
          },
          timeline: <TimelineEntry>[
            _t(_d(26, 14, 20), 'Tạo đơn (online)'),
            _t(_d(26, 16, 5), 'Admin đã duyệt'),
            _t(_d(27, 8, 40), 'Kho đã xuất hàng'),
            _t(_d(27, 9, 15), 'Đang giao'),
          ]),
      _order(
          s,
          'DH-001019',
          '10004135',
          const <CartLine>[
            CartLine(sku: 'SKU003', qty: 30),
            CartLine(sku: 'SKU004', qty: 12)
          ],
          OrderStatus.delivered,
          _d(24, 10, 30),
          pay: PaymentMethod.prepaid,
          paid: true,
          paidAt: _d(24, 16, 40),
          timeline: <TimelineEntry>[
            _t(_d(24, 10, 30), 'Tạo đơn (online)'),
            _t(_d(24, 11, 2), 'Operator đã duyệt'),
            _t(_d(24, 14, 10), 'Kho đã xuất hàng'),
            _t(_d(24, 16, 40), 'Retailer quét QR xác nhận đã nhận'),
          ]),
      _order(
          s,
          'DH-001018',
          '10004127',
          const <CartLine>[CartLine(sku: 'SKU004', qty: 90)],
          OrderStatus.rejected,
          _d(23, 16, 45),
          reason:
              'Không đủ hàng khả dụng: SKU004 cần 90 thùng, chỉ còn 64 thùng.',
          timeline: <TimelineEntry>[
            _t(_d(23, 16, 45), 'Tạo đơn (online)'),
            _t(_d(23, 16, 45), 'Hệ thống tự động từ chối - không đủ hàng'),
          ]),
      _order(
          s,
          'DH-001015',
          '10004127',
          const <CartLine>[
            CartLine(sku: 'SKU001', qty: 45),
            CartLine(sku: 'SKU005', qty: 10)
          ],
          OrderStatus.delivered,
          _d(25, 10, 40),
          paid: true,
          paidAt: _d(26, 10, 5),
          pointsEarned: 142,
          timeline: <TimelineEntry>[
            _t(_d(25, 10, 40), 'Sales tạo đơn'),
            _t(_d(25, 11, 15), 'Đã duyệt'),
            _t(_d(26, 8, 30), 'Kho đã xuất hàng'),
            _t(_d(26, 10, 5), 'Đã quét QR xác nhận nhận hàng, thanh toán COD'),
          ]),
      _order(
          s,
          'DH-000994',
          '10004127',
          const <CartLine>[CartLine(sku: 'SKU003', qty: 25)],
          OrderStatus.delivered,
          _d(18, 8, 50),
          pay: PaymentMethod.credit,
          term: 14,
          due: DateTime(2026, 10, 2),
          timeline: <TimelineEntry>[
            _t(_d(18, 8, 50), 'Sales tạo đơn - công nợ trả sau 14 ngày'),
            _t(_d(18, 9, 20), 'Đã duyệt'),
            _t(_d(18, 15, 5),
                'Đã quét QR xác nhận nhận hàng - ghi nợ, hạn trả 02/10'),
          ]),
      _order(
          s,
          'DH-001012',
          '10004127',
          const <CartLine>[
            CartLine(sku: 'SKU002', qty: 40),
            CartLine(sku: 'SKU005', qty: 15)
          ],
          OrderStatus.delivered,
          _d(14, 9, 10),
          pay: PaymentMethod.prepaid,
          paid: true,
          paidAt: _d(14, 9, 40),
          timeline: <TimelineEntry>[
            _t(_d(14, 9, 10), 'Sales tạo đơn'),
            _t(_d(14, 9, 40), 'Đã duyệt'),
            _t(_d(15, 13, 30), 'Kho đã xuất hàng'),
            _t(_d(15, 15, 20), 'Đã quét QR xác nhận nhận hàng'),
          ]),
      _order(
          s,
          'DH-001006',
          '10004127',
          const <CartLine>[
            CartLine(sku: 'SKU003', qty: 30),
            CartLine(sku: 'SKU004', qty: 12)
          ],
          OrderStatus.delivered,
          _d(5, 10, 5),
          paid: true,
          paidAt: _d(6, 9, 0),
          timeline: <TimelineEntry>[
            _t(_d(5, 10, 5), 'Sales tạo đơn'),
            _t(_d(6, 9, 0), 'Đã giao, thanh toán COD'),
          ]),
      _order(
          s,
          'DH-000987',
          '10004219',
          const <CartLine>[CartLine(sku: 'SKU002', qty: 20)],
          OrderStatus.delivered,
          _d(15, 9, 40),
          pay: PaymentMethod.credit,
          term: 7,
          due: DateTime(2026, 9, 22),
          timeline: <TimelineEntry>[
            _t(_d(15, 9, 40), 'Sales tạo đơn - công nợ trả sau 7 ngày'),
            _t(_d(15, 15, 0),
                'Đã quét QR xác nhận nhận hàng - ghi nợ, hạn trả 22/09'),
          ]),
    ]);
    s.nextOrderNo = 1031;
  }

  // -------------------------------------------------------------- warehouse

  static LabelInfo _label(
    String code,
    String sku,
    String batch,
    DateTime exp,
    int qty,
    LabelStatus status,
    String loc, {
    String wh = 'Kho Thới An',
    String parent = '',
    String picking = '',
    String order = '',
    List<String> children = const <String>[],
    List<TimelineEntry> history = const <TimelineEntry>[],
    required Map<String, Product> products,
  }) =>
      LabelInfo(
        code: code,
        sku: sku,
        name: products[sku]?.name ?? sku,
        batchCode: batch,
        qty: qty,
        status: status,
        expiry: exp,
        location: loc,
        warehouseName: wh,
        parentCode: parent,
        pickingCode: picking,
        orderCode: order,
        children: children,
        history: history,
      );

  static PickingLine _line(int i, String sku, String name, String batch,
          DateTime exp, String loc, int need, String suggest,
          {int picked = 0, String out = ''}) =>
      PickingLine(
          index: i,
          sku: sku,
          name: name,
          batchCode: batch,
          expiry: exp,
          location: loc,
          need: need,
          suggestedLabel: suggest,
          picked: picked,
          outLabel: out);

  static void _warehouse(MockStore s) {
    final pm = s.productMap;
    final exp1 = DateTime(2026, 10, 18);
    final exp3 = DateTime(2026, 10, 24);
    void add(LabelInfo l) => s.labels[l.code] = l;

    add(_label('TEM-000118', 'SKU001', 'WH-TA-SKU001-18102026', exp1, 40,
        LabelStatus.inStock, 'A-03',
        children: const <String>['TEM-000160', 'TEM-000187'],
        history: <TimelineEntry>[
          TimelineEntry(
              time: _d(15, 7, 30),
              label: 'Nhập kho PN-260915-01 (100 thùng)',
              delta: '+100'),
          TimelineEntry(
              time: _d(22, 10, 10),
              label: 'Tách tem con TEM-000160 cho DH-001012A',
              delta: '−20'),
          TimelineEntry(
              time: _d(27, 8, 20),
              label: 'Tách tem con TEM-000187 cho DH-001021A',
              delta: '−40'),
        ],
        products: pm));
    add(_label('TEM-000131', 'SKU003', 'WH-TA-SKU003-24102026', exp3, 30,
        LabelStatus.inStock, 'B-01',
        children: const <String>['TEM-000165', 'TEM-000176', 'TEM-000188'],
        history: <TimelineEntry>[
          TimelineEntry(
              time: _d(16, 7, 45),
              label: 'Nhập kho PN-260916-01 (60 thùng)',
              delta: '+60'),
          TimelineEntry(
              time: _d(20, 9, 15),
              label: 'Tách tem con TEM-000165 cho DH-000997A',
              delta: '−10'),
          TimelineEntry(
              time: _d(24, 13, 5),
              label: 'Tách tem con TEM-000176 cho DH-001019B',
              delta: '−10'),
          TimelineEntry(
              time: _d(27, 8, 25),
              label: 'Tách tem con TEM-000188 cho DH-001021A',
              delta: '−10'),
        ],
        products: pm));
    add(_label('TEM-000142', 'SKU002', 'WH-TA-SKU002-20102026',
        DateTime(2026, 10, 20), 100, LabelStatus.inStock, 'C-02',
        history: <TimelineEntry>[
          TimelineEntry(
              time: _d(27, 7, 20),
              label: 'Nhập kho PN-260927-01 (100 thùng)',
              delta: '+100')
        ],
        products: pm));
    add(_label('TEM-000099', 'SKU001', 'WH-TA-SKU001-25092026',
        DateTime(2026, 9, 25), 10, LabelStatus.expired, 'A-01',
        history: <TimelineEntry>[
          TimelineEntry(
              time: DateTime(2026, 8, 20, 7, 30),
              label: 'Nhập kho PN-260820-02 (10 thùng)',
              delta: '+10'),
          TimelineEntry(
              time: _d(25, 0, 0),
              label: 'Hệ thống chuyển Hết hạn - chờ lập phiếu hủy'),
        ],
        products: pm));
    add(_label('TEM-000187', 'SKU001', 'WH-TA-SKU001-18102026', exp1, 40,
        LabelStatus.inTransit, '-',
        parent: 'TEM-000118',
        picking: 'DH-001021A',
        order: 'DH-001021',
        history: <TimelineEntry>[
          TimelineEntry(
              time: _d(27, 8, 20),
              label: 'Tách từ TEM-000118 cho DH-001021A',
              delta: '+40'),
          TimelineEntry(time: _d(27, 8, 40), label: 'Xác nhận xuất DH-001021A'),
        ],
        products: pm));
    add(_label('TEM-000188', 'SKU003', 'WH-TA-SKU003-24102026', exp3, 10,
        LabelStatus.inTransit, '-',
        parent: 'TEM-000131',
        picking: 'DH-001021A',
        order: 'DH-001021',
        products: pm));
    add(_label('TEM-000192', 'SKU001', 'WH-TD-SKU001-18102026', exp1, 20,
        LabelStatus.inTransit, '-',
        wh: 'Kho Thủ Đức',
        picking: 'DH-001021B',
        order: 'DH-001021',
        products: pm));
    add(_label('TEM-000195', 'SKU003', 'WH-GV-SKU003-14102026',
        DateTime(2026, 10, 14), 20, LabelStatus.inTransit, '-',
        wh: 'Kho Gò Vấp',
        picking: 'DH-001021C',
        order: 'DH-001021',
        products: pm));
    add(_label('TEM-000204', 'SKU001', 'WH-TA-SKU001-18102026', exp1, 10,
        LabelStatus.picked, '-',
        picking: 'DH-001024B', order: 'DH-001024', products: pm));
    // Labels of the incoming transfers (sent by other warehouses).
    add(_label('TEM-000210', 'SKU002', 'WH-GV-SKU002-12102026',
        DateTime(2026, 10, 12), 30, LabelStatus.inTransit, '-',
        wh: 'Kho Gò Vấp',
        history: <TimelineEntry>[
          TimelineEntry(
              time: _d(26, 15, 30),
              label: 'Xuất kho theo phiếu DC-260926-01 (Luân chuyển cận hạn)')
        ],
        products: pm));
    add(_label('TEM-000211', 'SKU001', 'WH-TCH-SKU001-30102026',
        DateTime(2026, 10, 30), 50, LabelStatus.inTransit, '-',
        wh: 'Kho Tân Chánh Hiệp', products: pm));
    add(_label('TEM-000212', 'SKU003', 'WH-TCH-SKU003-05112026',
        DateTime(2026, 11, 5), 40, LabelStatus.inTransit, '-',
        wh: 'Kho Tân Chánh Hiệp', products: pm));

    final n1 = pm['SKU001']!.name;
    final n3 = pm['SKU003']!.name;
    s.pickings['DH-001024A'] = PickingList(
      code: 'DH-001024A',
      orderCode: 'DH-001024',
      retailerCode: '10004182',
      retailerName: 'Cửa hàng tiện lợi An Phú',
      status: PickingStatus.pending,
      warehouseName: 'Kho Thới An',
      approvedAt: _d(27, 8, 32),
      siblingText:
          'DH-001024B · Kho Tân Chánh Hiệp · 10 thùng SKU001 · Chưa pick',
      lines: <PickingLine>[
        _line(0, 'SKU001', n1, 'WH-TA-SKU001-18102026', exp1, 'A-03', 40,
            'TEM-000118'),
        _line(1, 'SKU003', n3, 'WH-TA-SKU003-24102026', exp3, 'B-01', 20,
            'TEM-000131'),
      ],
    );
    s.pickings['DH-001021A'] = PickingList(
      code: 'DH-001021A',
      orderCode: 'DH-001021',
      retailerCode: '10004127',
      retailerName: 'Tạp hóa Minh Châu',
      status: PickingStatus.shipped,
      warehouseName: 'Kho Thới An',
      approvedAt: _d(26, 16, 5),
      shippedAt: _d(27, 8, 40),
      siblingText:
          'DH-001021B (Kho Thủ Đức), DH-001021C (Kho Gò Vấp) · Đã xuất',
      lines: <PickingLine>[
        _line(0, 'SKU001', n1, 'WH-TA-SKU001-18102026', exp1, 'A-03', 40,
            'TEM-000118',
            picked: 40, out: 'TEM-000187'),
        _line(1, 'SKU003', n3, 'WH-TA-SKU003-24102026', exp3, 'B-01', 10,
            'TEM-000131',
            picked: 10, out: 'TEM-000188'),
      ],
    );
    s.pickings['DH-001019B'] = PickingList(
      code: 'DH-001019B',
      orderCode: 'DH-001019',
      retailerCode: '10004135',
      retailerName: 'Siêu thị mini Hòa Bình',
      status: PickingStatus.shipped,
      warehouseName: 'Kho Thới An',
      approvedAt: _d(24, 11, 2),
      shippedAt: _d(24, 14, 10),
      siblingText:
          'DH-001019A (Kho Gò Vấp), DH-001019C (Kho Tân Chánh Hiệp) · Đã xuất',
      lines: <PickingLine>[
        _line(0, 'SKU003', n3, 'WH-TA-SKU003-24102026', exp3, 'B-01', 10,
            'TEM-000131',
            picked: 10, out: 'TEM-000176'),
      ],
    );

    s.transfers.addAll(<Transfer>[
      Transfer(
        code: 'DC-260926-01',
        kind: TransferKind.nearExpiryRotation,
        status: TransferStatus.inTransit,
        fromWarehouse: 'Kho Gò Vấp (WH-GV)',
        toWarehouse: 'Kho Thới An (WH-TA)',
        shippedAt: _d(26, 15, 30),
        expectedAt: _d(27, 12, 0),
        distanceKm: 9,
        note:
            'Luân chuyển cận hạn: lô WH-GV-SKU002-12102026 còn 15 ngày, Kho Thới An bán nhanh hơn (điểm 0,667).',
        lines: <TransferLine>[
          TransferLine(
              sku: 'SKU002',
              name: pm['SKU002']!.name,
              batchCode: 'WH-GV-SKU002-12102026',
              qty: 30,
              labelCode: 'TEM-000210',
              expiry: DateTime(2026, 10, 12)),
        ],
      ),
      Transfer(
        code: 'DC-260926-02',
        kind: TransferKind.replenishment,
        status: TransferStatus.inTransit,
        fromWarehouse: 'Kho Tân Chánh Hiệp (WH-TCH)',
        toWarehouse: 'Kho Thới An (WH-TA)',
        shippedAt: _d(26, 16, 0),
        expectedAt: _d(27, 14, 0),
        distanceKm: 14,
        note: 'Bổ sung tồn kho theo kế hoạch tuần.',
        lines: <TransferLine>[
          TransferLine(
              sku: 'SKU001',
              name: n1,
              batchCode: 'WH-TCH-SKU001-30102026',
              qty: 50,
              labelCode: 'TEM-000211',
              expiry: DateTime(2026, 10, 30)),
          TransferLine(
              sku: 'SKU003',
              name: n3,
              batchCode: 'WH-TCH-SKU003-05112026',
              qty: 40,
              labelCode: 'TEM-000212',
              expiry: DateTime(2026, 11, 5)),
        ],
      ),
      Transfer(
        code: 'DC-260920-01',
        kind: TransferKind.replenishment,
        status: TransferStatus.received,
        fromWarehouse: 'Kho Thủ Đức (WH-TD)',
        toWarehouse: 'Kho Thới An (WH-TA)',
        shippedAt: _d(20, 8, 0),
        expectedAt: _d(20, 15, 0),
        receivedAt: _d(20, 14, 30),
        distanceKm: 18,
        lines: <TransferLine>[
          TransferLine(
              sku: 'SKU006',
              name: pm['SKU006']!.name,
              batchCode: 'WH-TD-SKU006-04102026',
              qty: 40,
              labelCode: 'TEM-000150',
              expiry: DateTime(2026, 10, 4),
              received: true),
        ],
      ),
    ]);
  }

  // ---------------------------------------------------------------- finance

  static void _finance(MockStore s) {
    s.receivables.addAll(<Receivable>[
      Receivable(
        orderCode: 'DH-000987',
        retailerCode: '10004219',
        retailerName: 'Tạp hóa Thanh Xuân',
        amount: 4200000,
        status: ReceivableStatus.overdue,
        deliveredAt: _d(15, 15, 0),
        dueDate: DateTime(2026, 9, 22),
        term: 7,
      ),
      Receivable(
        orderCode: 'DH-000994',
        retailerCode: '10004127',
        retailerName: 'Tạp hóa Minh Châu',
        amount: 8000000,
        status: ReceivableStatus.unpaid,
        deliveredAt: _d(18, 15, 5),
        dueDate: DateTime(2026, 10, 2),
        term: 14,
      ),
    ]);
  }

  // ---------------------------------------------------------------- loyalty

  static void _loyalty(MockStore s) {
    s.loyalty['10004127'] = MockLoyalty(
      balance: 412,
      ledger: <PointLedgerEntry>[
        PointLedgerEntry(
            date: _d(27, 9, 15),
            description: 'DH-001021 · đang giao - cộng khi quét QR nhận hàng',
            points: 238,
            kind: PointKind.pending,
            orderCode: 'DH-001021'),
        PointLedgerEntry(
            date: _d(25, 10, 40),
            description: 'DH-001015 · quét QR nhận hàng',
            points: 142,
            kind: PointKind.earned,
            orderCode: 'DH-001015'),
        PointLedgerEntry(
            date: _d(18, 15, 5),
            description: 'DH-000994 · công nợ - cộng khi đã thanh toán',
            points: 80,
            kind: PointKind.pending,
            orderCode: 'DH-000994'),
        PointLedgerEntry(
            date: _d(15, 15, 20),
            description: 'DH-001012 · quét QR nhận hàng',
            points: 125,
            kind: PointKind.earned,
            orderCode: 'DH-001012'),
        PointLedgerEntry(
            date: _d(10, 9, 0),
            description: 'Đổi quà QUA-005 Áo thun đồng phục · DQ-260910-01',
            points: -50,
            kind: PointKind.redeemed),
        PointLedgerEntry(
            date: _d(6, 9, 0),
            description: 'DH-001006 · nhận hàng',
            points: 135,
            kind: PointKind.earned,
            orderCode: 'DH-001006'),
      ],
    );
    s.gifts.addAll(const <Gift>[
      Gift(code: 'QUA-005', name: 'Áo thun đồng phục', points: 50, stock: 40),
      Gift(
          code: 'QUA-003',
          name: 'Bộ ly thủy tinh 6 cái',
          points: 120,
          stock: 29),
      Gift(
          code: 'QUA-001',
          name: 'Ô dù che nắng cửa hàng',
          points: 200,
          stock: 15),
      Gift(
          code: 'QUA-002',
          name: 'Thùng đá giữ lạnh 30L',
          points: 350,
          stock: 8),
      Gift(code: 'QUA-004', name: 'Tủ mát mini 90L', points: 1500, stock: 2),
    ]);
    s.redemptions.add(GiftRedemption(
      code: 'DQ-260910-01',
      giftCode: 'QUA-005',
      giftName: 'Áo thun đồng phục',
      points: 50,
      status: GiftRequestStatus.done,
      requestedAt: _d(10, 9, 0),
    ));
    s.nextRedemptionNo = 2;
  }

  // ------------------------------------------------------------ performance

  static void _performance(MockStore s) {
    void sale(String code, String rid, int day, int hh, int mm, int rev,
            int after) =>
        s.sales.add(MockSale(
            orderCode: code,
            retailerCode: rid,
            createdAt: _d(day, hh, mm),
            revenue: rev,
            afterPromo: after));
    sale('DH-000948', '10004135', 2, 9, 10, 21600000, 20950000);
    sale('DH-001006', '10004127', 5, 10, 5, 13920000, 13502400);
    sale('DH-000961', '10004182', 8, 10, 5, 12400000, 12400000);
    sale('DH-000970', '10004135', 11, 8, 40, 16800000, 16300000);
    sale('DH-000976', '10004219', 13, 15, 30, 9600000, 9600000);
    sale('DH-001012', '10004127', 14, 9, 10, 12900000, 12564000);
    sale('DH-000987', '10004219', 15, 9, 40, 4200000, 4200000);
    sale('DH-000990', '10004219', 18, 11, 20, 7200000, 7200000);
    sale('DH-000994', '10004127', 18, 8, 50, 8000000, 8000000);
    sale('DH-000997', '10004135', 20, 10, 0, 19350000, 19350000);
    sale('DH-001003', '10004182', 21, 16, 10, 11800000, 11800000);
    sale('DH-001009', '10004182', 22, 9, 30, 8400000, 8400000);
    sale('DH-001013', '10004219', 23, 14, 0, 10400000, 10400000);
    sale('DH-001015', '10004127', 25, 10, 40, 14250000, 14250000);
    s.people.addAll(const <MockPerson>[
      MockPerson('Trần Thị Bình', 'Q12-A', 272400000, 245700000),
      MockPerson('Lê Minh Hoàng', 'Q12-B', 238100000, 235200000),
      MockPerson('Phạm Thu Hà', 'Q12-B', 176200000, 171400000),
      MockPerson('Võ Quốc Huy', 'Q12-A', 151900000, 150300000),
      MockPerson('Đặng Mỹ Linh', 'Q12-B', 143500000, 129800000),
      MockPerson('Huỳnh Gia Bảo', 'Q12-A', 128400000, 126900000),
      MockPerson('Ngô Thanh Tâm', 'Q12-B', 97600000, 94100000),
    ]);
    s.topProducts.addAll(<List<Object>>[
      <Object>['SKU001', 1240, 297800000],
      <Object>['SKU003', 980, 301900000],
      <Object>['SKU002', 760, 155300000],
      <Object>['SKU005', 640, 179200000],
      <Object>['SKU004', 410, 143100000],
      <Object>['SKU006', 380, 99600000],
      <Object>['SKU007', 120, 63500000],
    ]);
  }

  // ---------------------------------------------------------- notifications

  static void _notifications(MockStore s) {
    final sales = s.users[0];
    final wk = s.users[1];
    final rt = s.users[2];
    s.notifications[MockStore.notificationKey(sales)] = <AppNotification>[
      AppNotification(
          id: 'N-S4',
          text:
              'Công nợ DH-000987 (Tạp hóa Thanh Xuân) đã quá hạn 22/09 - cần thu 4.200.000đ.',
          createdAt: _d(27, 8, 0),
          kind: 'debt'),
      AppNotification(
          id: 'N-S1',
          text: 'Đơn DH-001024 (Cửa hàng tiện lợi An Phú) đã được duyệt.',
          createdAt: _d(27, 8, 32),
          orderCode: 'DH-001024',
          kind: 'order'),
      AppNotification(
          id: 'N-S2',
          text: 'Đơn DH-001021 (Tạp hóa Minh Châu) đang được giao.',
          createdAt: _d(27, 9, 15),
          orderCode: 'DH-001021',
          kind: 'order',
          unread: false),
      AppNotification(
          id: 'N-S3',
          text:
              'Đơn DH-001018 bị từ chối: không đủ hàng khả dụng cho SKU004. Đã báo cho retailer.',
          createdAt: _d(23, 16, 45),
          orderCode: 'DH-001018',
          kind: 'order',
          unread: false),
    ];
    s.notifications[MockStore.notificationKey(wk)] = <AppNotification>[
      AppNotification(
          id: 'N-W1',
          text:
              'Picking list mới DH-001024A (Cửa hàng tiện lợi An Phú) - Operator Lý Thu Trang vừa duyệt đơn.',
          createdAt: _d(27, 8, 32),
          orderCode: 'DH-001024A',
          kind: 'picking'),
      AppNotification(
          id: 'N-W4',
          text:
              'Phiếu luân chuyển cận hạn DC-260926-01 từ Kho Gò Vấp đang trên đường, chuẩn bị nhận 30 thùng SKU002.',
          createdAt: _d(26, 15, 30),
          orderCode: 'DC-260926-01',
          kind: 'transfer'),
      AppNotification(
          id: 'N-W2',
          text:
              'Batch WH-TA-SKU001-25092026 (tem TEM-000099) đã hết hạn - lập phiếu hủy trên Portal.',
          createdAt: _d(25, 0, 0),
          orderCode: 'TEM-000099',
          kind: 'label'),
      AppNotification(
          id: 'N-W3',
          text: 'Đơn DH-001021 đã được retailer xác nhận nhận hàng.',
          createdAt: _d(27, 10, 32),
          kind: 'order',
          unread: false),
    ];
    s.notifications[MockStore.notificationKey(rt)] = <AppNotification>[
      AppNotification(
          id: 'N-R1',
          text:
              'Đơn DH-001021 đang được giao đến cửa hàng. Chuẩn bị quét QR khi nhận hàng.',
          createdAt: _d(27, 9, 15),
          orderCode: 'DH-001021',
          kind: 'order'),
      AppNotification(
          id: 'N-R2',
          text: 'Đơn DH-001018 bị từ chối: không đủ hàng khả dụng cho SKU004.',
          createdAt: _d(23, 16, 45),
          orderCode: 'DH-001018',
          kind: 'order',
          unread: false),
      AppNotification(
          id: 'N-R3',
          text: 'Đơn DH-001012 đã giao thành công. Cảm ơn bạn đã xác nhận.',
          createdAt: _d(15, 15, 20),
          orderCode: 'DH-001012',
          kind: 'order',
          unread: false),
    ];
  }

  // ---------------------------------------------------------- registrations

  static void _registrations(MockStore s) {
    s.registrations.addAll(<RetailerRegistration>[
      RetailerRegistration(
        code: 'KB-0012',
        name: 'Tạp hóa Hải Yến',
        address: '31 Trường Chinh, P. Tân Thới Nhất, Q.12',
        contactName: 'Chị Hải Yến',
        phone: '0903 456 789',
        areaName: 'Quận 12',
        status: RegistrationStatus.waiting,
        potential: const RetailerPotential(
            size: 'M',
            areaM2: 32,
            fridges: 2,
            forecastRevenue: 35000000,
            capacityCases: 70,
            frequency: '2 lần/tuần',
            grade: 'B'),
        timeline: <TimelineEntry>[
          TimelineEntry(time: _d(26, 9, 20), label: 'Bạn gửi khai báo')
        ],
      ),
      RetailerRegistration(
        code: 'KB-0011',
        name: 'Tạp hóa Ngọc Lan',
        address: '19 Phan Văn Hớn, X. Xuân Thới Thượng, Hóc Môn',
        contactName: 'Anh Tuấn',
        phone: '0918 222 105',
        areaName: 'Hóc Môn',
        status: RegistrationStatus.approved,
        retailerCode: '10004256',
        potential: const RetailerPotential(
            size: 'S',
            areaM2: 20,
            fridges: 1,
            forecastRevenue: 18000000,
            capacityCases: 35,
            grade: 'C'),
        timeline: <TimelineEntry>[
          TimelineEntry(time: _d(17, 15, 10), label: 'Bạn gửi khai báo'),
          TimelineEntry(
              time: _d(18, 9, 0),
              label:
                  'Operator Lê Thu duyệt - cấp mã 10004256 và tài khoản Retailer App'),
          TimelineEntry(
              time: _d(18, 9, 5),
              label:
                  'Gán cho khu vực Hóc Môn - ngoài khu vực của nhóm Q12-A, nhóm phụ trách Hóc Môn sẽ đặt hàng'),
        ],
      ),
      RetailerRegistration(
        code: 'KB-0009',
        name: 'Quán nước Út Mười',
        address: '90 Nguyễn Ảnh Thủ, P. Hiệp Thành, Q.12',
        contactName: 'Chú Mười',
        phone: '0908 771 002',
        areaName: 'Quận 12',
        status: RegistrationStatus.rejected,
        reason:
            'Trùng địa chỉ với điểm bán 10004182 (Cửa hàng tiện lợi An Phú).',
        potential: const RetailerPotential(),
        timeline: <TimelineEntry>[
          TimelineEntry(time: _d(15, 8, 45), label: 'Bạn gửi khai báo'),
          TimelineEntry(time: _d(15, 11, 20), label: 'Operator Lê Thu từ chối'),
        ],
      ),
    ]);
    s.nextRegistrationNo = 13;
  }
}
