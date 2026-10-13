import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/loyalty.dart';
import 'package:fscm_mobile/data/models/receivable.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';

/// `/receivables`, `/loyalty`, `/gifts`, `/gift-redemptions`, `/complaints`,
/// `/kpi`, `/rankings`.
class MockFinanceHandler extends MockHandler {
  MockFinanceHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;
    if (user == null) return null;

    if (r.matches('GET', '/receivables')) return _receivables(user, r);
    if (r.matches('POST', '/receivables/*/collect')) {
      return _collect(user, r.segments[1]);
    }

    if (r.matches('GET', '/loyalty/programs')) {
      return MockReply.page(<Map<String, dynamic>>[_program().toJson()]);
    }
    if (r.matches('GET', '/loyalty/retailers/*')) {
      return _account(r.segments[2]);
    }
    if (r.matches('GET', '/gifts')) {
      return MockReply.page(store.gifts.map((g) => g.toJson()).toList());
    }
    if (r.matches('GET', '/gift-redemptions')) {
      return MockReply.page(store.redemptions.map((g) => g.toJson()).toList());
    }
    if (r.matches('POST', '/gift-redemptions')) return _redeem(user, r.body);

    if (r.matches('GET', '/complaints')) {
      return MockReply.page(store.complaints.map(_complaintJson).toList());
    }
    if (r.matches('POST', '/complaints')) return _complain(user, r.body);

    if (r.matches('GET', '/kpi/sales')) return _kpi(r.queryStr('period'));
    if (r.matches('GET', '/rankings/sales')) {
      return _salesRanking(user, r.queryStr('period'));
    }
    if (r.matches('GET', '/rankings/products')) return _productRanking();
    return null;
  }

  // ----------------------------------------------------------- receivables

  List<Receivable> _visibleReceivables(MockUser user) {
    final now = store.now();
    final today = DateTime(now.year, now.month, now.day);
    return store.receivables.where((x) {
      if (user.role == UserRole.retailer) {
        return x.retailerCode == user.retailerCode;
      }
      final retailer = store.retailer(x.retailerCode);
      return retailer != null && retailer.areaCode == user.areaCode;
    }).map((x) {
      if (x.isPaid) return x;
      final due = x.dueDate;
      final overdue = due != null && due.isBefore(today);
      return x.copyWith(
          status: overdue ? ReceivableStatus.overdue : ReceivableStatus.unpaid);
    }).toList();
  }

  ApiResponse _receivables(MockUser user, MockRequest r) {
    final status = r.queryStr('status').toLowerCase();
    final list = _visibleReceivables(user)
        .where((x) => status.isEmpty || x.status.code.toLowerCase() == status)
        .toList()
      ..sort((a, b) =>
          (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
    return MockReply.page(list.map((x) => x.toJson()).toList());
  }

  ApiResponse _collect(MockUser user, String orderCode) {
    final i = store.receivables.indexWhere((x) => x.orderCode == orderCode);
    if (i < 0) return MockReply.notFound('công nợ $orderCode');
    final current = store.receivables[i];
    if (current.isPaid) {
      return MockReply.conflict('Công nợ $orderCode đã được thu đủ.');
    }
    final now = store.now();
    final paid = current.copyWith(status: ReceivableStatus.paid, paidAt: now);
    store.receivables[i] = paid;

    final order = store.orderByCode(orderCode);
    if (order != null) {
      store.replaceOrder(order.copyWith(
        paid: true,
        paidAt: now,
        timeline: <TimelineEntry>[
          ...order.timeline,
          TimelineEntry(time: now, label: 'Sales ghi nhận đã thu đủ tiền mặt'),
        ],
      ));
    }
    // Loyalty: Pending -> Earned.
    final loyalty = store.loyalty[current.retailerCode];
    if (loyalty != null) {
      final idx = loyalty.ledger.indexWhere(
          (e) => e.orderCode == orderCode && e.kind == PointKind.pending);
      if (idx >= 0) {
        final e = loyalty.ledger[idx];
        loyalty.ledger[idx] = PointLedgerEntry(
          date: now,
          description: '$orderCode · đã thanh toán công nợ',
          points: e.points,
          kind: PointKind.earned,
          orderCode: orderCode,
        );
        loyalty.balance += e.points;
      }
    }
    return MockReply.ok(paid.toJson());
  }

  // --------------------------------------------------------------- loyalty

  LoyaltyProgram _program() => const LoyaltyProgram(
        code: 'LP-001',
        name: 'Tích điểm đổi quà 2026',
        amountPerPoint: 100000,
        expiryText: 'Điểm có hiệu lực đến 31/12/2026',
      );

  ApiResponse _account(String retailerCode) {
    final retailer = store.retailer(retailerCode);
    final state = store.loyalty[retailerCode] ?? MockLoyalty(balance: 0);
    final account = LoyaltyAccount(
      retailerCode: retailerCode,
      balance: state.balance,
      pending: state.pending,
      held: state.held,
      tier: retailer?.tier ?? '',
      program: _program(),
      ledger: List<PointLedgerEntry>.of(state.ledger)
        ..sort((a, b) =>
            (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000))),
    );
    return MockReply.ok(account.toJson());
  }

  ApiResponse _redeem(MockUser user, Map<String, dynamic> body) {
    final code = user.retailerCode;
    if (user.role != UserRole.retailer || code == null) {
      return MockReply.forbidden('Chỉ điểm bán mới đổi quà.');
    }
    final gi = store.gifts.indexWhere((g) => g.code == asStr(body['giftCode']));
    if (gi < 0) return MockReply.notFound('quà tặng');
    final gift = store.gifts[gi];
    final state =
        store.loyalty.putIfAbsent(code, () => MockLoyalty(balance: 0));
    if (gift.stock <= 0) return MockReply.conflict('Quà ${gift.name} đã hết.');
    if (state.balance < gift.points) {
      return MockReply.conflict(
          'Không đủ điểm: cần ${gift.points} điểm, bạn có ${state.balance} điểm.');
    }
    final now = store.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final prefix = 'DQ-$yy$mm$dd-';
    final seq =
        store.redemptions.where((x) => x.code.startsWith(prefix)).length + 1;
    final redemption = GiftRedemption(
      code: '$prefix${seq.toString().padLeft(2, '0')}',
      giftCode: gift.code,
      giftName: gift.name,
      points: gift.points,
      status: GiftRequestStatus.requested,
      requestedAt: now,
    );
    store.redemptions.insert(0, redemption);
    state.balance -= gift.points;
    state.ledger.insert(
      0,
      PointLedgerEntry(
        date: now,
        description:
            'Giữ điểm đổi quà ${gift.code} ${gift.name} · ${redemption.code}',
        points: -gift.points,
        kind: PointKind.held,
      ),
    );
    store.gifts[gi] = Gift(
        code: gift.code,
        name: gift.name,
        points: gift.points,
        stock: gift.stock - 1);
    return MockReply.created(redemption.toJson());
  }

  // ------------------------------------------------------------ complaints

  Map<String, dynamic> _complaintJson(Complaint c) => <String, dynamic>{
        'code': c.code,
        'orderCode': c.orderCode,
        'sku': c.sku,
        'name': c.name,
        'expectedQty': c.expectedQty,
        'actualQty': c.actualQty,
        'status': c.status.code,
        'labelCode': c.labelCode,
        'note': c.note,
        'createdAt': isoOrNull(c.createdAt),
        'response': c.response,
      };

  ApiResponse _complain(MockUser user, Map<String, dynamic> body) {
    final order = store.orderByCode(asStr(body['orderCode']));
    if (order == null || order.retailerCode != user.retailerCode) {
      return MockReply.notFound('đơn hàng cần khiếu nại');
    }
    final sku = asStr(body['sku']);
    final lineMatches = order.lines.where((l) => l.sku == sku);
    if (lineMatches.isEmpty) {
      return MockReply.invalid('Sản phẩm không thuộc đơn hàng.');
    }
    final line = lineMatches.first;
    final now = store.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final complaint = Complaint(
      code:
          'KN-$yy$mm$dd-${(store.nextComplaintNo++).toString().padLeft(2, '0')}',
      orderCode: order.code,
      sku: sku,
      name: line.name,
      expectedQty: line.qty,
      actualQty: asInt(body['actualQty']),
      status: ComplaintStatus.open,
      labelCode: asStr(body['labelCode']),
      note: asStr(body['note']),
      createdAt: now,
    );
    store.complaints.insert(0, complaint);
    return MockReply.created(_complaintJson(complaint));
  }

  // ----------------------------------------------------------- performance

  List<MockSale> _salesIn(String period) {
    final now = store.now();
    return store.sales.where((s) {
      switch (period) {
        case 'today':
          return s.createdAt.year == now.year &&
              s.createdAt.month == now.month &&
              s.createdAt.day == now.day;
        case '7d':
        case 'week':
          return now.difference(s.createdAt).inDays < 7;
        default:
          return s.createdAt.year == now.year && s.createdAt.month == now.month;
      }
    }).toList();
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'today':
        return 'Hôm nay';
      case '7d':
      case 'week':
        return '7 ngày gần nhất';
      default:
        return 'Tháng 9/2026';
    }
  }

  ApiResponse _kpi(String period) {
    final list = _salesIn(period);
    final byRetailer = <String, List<MockSale>>{};
    for (final s in list) {
      byRetailer.putIfAbsent(s.retailerCode, () => <MockSale>[]).add(s);
    }
    final rows = byRetailer.entries.map((e) {
      return <String, dynamic>{
        'retailerCode': e.key,
        'retailerName': store.retailer(e.key)?.name ?? e.key,
        'orders': e.value.length,
        'revenueAfterPromo': e.value.fold<int>(0, (a, s) => a + s.afterPromo),
      };
    }).toList()
      ..sort((a, b) => asInt(b['revenueAfterPromo'])
          .compareTo(asInt(a['revenueAfterPromo'])));
    return MockReply.ok(<String, dynamic>{
      'periodLabel': _periodLabel(period),
      'orderCount': list.length,
      'revenue': list.fold<int>(0, (a, s) => a + s.revenue),
      'revenueAfterPromo': list.fold<int>(0, (a, s) => a + s.afterPromo),
      'target': store.salesTarget,
      'byRetailer': rows,
    });
  }

  ApiResponse _salesRanking(MockUser user, String period) {
    final mine = _salesIn('month');
    final entries = <MockPerson>[
      ...store.people,
      MockPerson(
        user.fullName,
        user.salesGroup ?? '',
        mine.fold<int>(0, (a, s) => a + s.revenue),
        mine.fold<int>(0, (a, s) => a + s.afterPromo),
      ),
    ]..sort((a, b) => b.afterPromo.compareTo(a.afterPromo));
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < entries.length; i++) {
      final p = entries[i];
      rows.add(<String, dynamic>{
        'rank': i + 1,
        'name': p.name,
        'group': p.group,
        'revenue': p.revenue,
        'revenueAfterPromo': p.afterPromo,
        'isMe': p.name == user.fullName,
      });
    }
    return MockReply.page(rows);
  }

  ApiResponse _productRanking() {
    final map = store.productMap;
    return MockReply.page(store.topProducts.map((t) {
      final sku = t[0] as String;
      return <String, dynamic>{
        'sku': sku,
        'name': map[sku]?.name ?? sku,
        'qty': t[1],
        'revenueAfterPromo': t[2],
      };
    }).toList());
  }
}
