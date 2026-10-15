import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/models/picking.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/data/models/transfer.dart';

/// `/picking-lists`, `/labels`, `/transfers`.
class MockWarehouseHandler extends MockHandler {
  MockWarehouseHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;
    if (user == null) return null;

    if (r.matches('GET', '/picking-lists')) return _listPickings(r);
    if (r.matches('GET', '/picking-lists/*')) {
      final p = store.pickings[r.segments[1]];
      return p == null
          ? MockReply.notFound('picking list ${r.segments[1]}')
          : MockReply.ok(p.toJson());
    }
    if (r.matches('POST', '/picking-lists/*/scan')) {
      return _scan(r.segments[1], r.body);
    }
    if (r.matches('POST', '/picking-lists/*/ship')) return _ship(r.segments[1]);

    if (r.matches('GET', '/labels/*')) return _label(user, r.segments[1]);

    if (r.matches('GET', '/transfers')) return _listTransfers(r);
    if (r.matches('GET', '/transfers/*')) {
      final t = _transfer(r.segments[1]);
      return t == null
          ? MockReply.notFound('phiếu ${r.segments[1]}')
          : MockReply.ok(t.toJson());
    }
    if (r.matches('POST', '/transfers/*/receive')) {
      return _receive(r.segments[1], r.body);
    }
    return null;
  }

  // --------------------------------------------------------------- picking

  ApiResponse _listPickings(MockRequest r) {
    final status = r.queryStr('status').toLowerCase();
    final list = store.pickings.values
        .where((p) => status.isEmpty || p.status.code.toLowerCase() == status)
        .toList()
      ..sort((a, b) => (b.approvedAt ?? DateTime(2000))
          .compareTo(a.approvedAt ?? DateTime(2000)));
    return MockReply.page(list.map((p) => p.toJson()).toList());
  }

  ApiResponse _scan(String code, Map<String, dynamic> body) {
    final list = store.pickings[code];
    if (list == null) return MockReply.notFound('picking list $code');
    if (list.isShipped) {
      return MockReply.conflict('Picking list $code đã xuất kho.');
    }
    final lineIndex = asInt(body['lineIndex']);
    if (lineIndex < 0 || lineIndex >= list.lines.length) {
      return MockReply.invalid('Dòng cần lấy không hợp lệ.');
    }
    final line = list.lines[lineIndex];
    final labelCode = asStr(body['labelCode']).trim().toUpperCase();
    final label = store.labels[labelCode];
    if (label == null) return MockReply.notFound('tem $labelCode');
    if (label.status != LabelStatus.inStock) {
      return MockReply.conflict(
          'Tem $labelCode đang ở trạng thái "${label.status.label}", không thể lấy hàng.');
    }
    if (label.sku != line.sku || label.batchCode != line.batchCode) {
      return MockReply.conflict(
        'Sai tem: $labelCode thuộc ${label.sku} · ${label.batchCode}; dòng cần lấy ${line.sku} · ${line.batchCode}. Quét lại tem ${line.suggestedLabel}.',
        code: 'WrongLabel',
      );
    }
    final remaining = line.need - line.picked;
    final qty = asInt(body['qty']);
    if (qty <= 0 || qty > remaining) {
      return MockReply.invalid('Số thùng lấy phải từ 1 đến $remaining.');
    }
    if (qty > label.qty) {
      return MockReply.invalid('Tem $labelCode chỉ còn ${label.qty} thùng.');
    }

    final now = store.now();
    String outLabel;
    String remainingLabel = '';
    int remainingQty = 0;
    if (qty == label.qty) {
      outLabel = label.code;
      store.labels[label.code] = label.copyWith(
        status: LabelStatus.picked,
        pickingCode: code,
        history: <TimelineEntry>[
          ...label.history,
          TimelineEntry(time: now, label: 'Lấy nguyên tem cho $code'),
        ],
      );
    } else {
      outLabel = store.newLabelCode();
      store.labels[outLabel] = LabelInfo(
        code: outLabel,
        sku: label.sku,
        name: label.name,
        batchCode: label.batchCode,
        qty: qty,
        status: LabelStatus.picked,
        expiry: label.expiry,
        location: '-',
        warehouseName: label.warehouseName,
        parentCode: label.code,
        pickingCode: code,
        orderCode: list.orderCode,
        history: <TimelineEntry>[
          TimelineEntry(
              time: now,
              label: 'Tách từ ${label.code} cho $code',
              delta: '+$qty'),
        ],
      );
      remainingLabel = label.code;
      remainingQty = label.qty - qty;
      store.labels[label.code] = label.copyWith(
        qty: remainingQty,
        children: <String>[...label.children, outLabel],
        history: <TimelineEntry>[
          ...label.history,
          TimelineEntry(
              time: now,
              label: 'Tách tem con $outLabel cho $code',
              delta: '−$qty'),
        ],
      );
    }

    final lines = List<PickingLine>.of(list.lines);
    lines[lineIndex] =
        line.copyWith(picked: line.picked + qty, outLabel: outLabel);
    final updated = list.copyWith(status: PickingStatus.picking, lines: lines);
    store.pickings[code] = updated;
    return MockReply.ok(<String, dynamic>{
      'list': updated.toJson(),
      'childLabel': outLabel,
      'remainingLabel': remainingLabel,
      'remainingQty': remainingQty,
      'pickedQty': qty,
    });
  }

  ApiResponse _ship(String code) {
    final list = store.pickings[code];
    if (list == null) return MockReply.notFound('picking list $code');
    if (list.isShipped) {
      return MockReply.conflict('Picking list $code đã xuất kho.');
    }
    if (!list.allDone) {
      return MockReply.conflict('Quét đủ tất cả dòng để xác nhận xuất.');
    }
    final now = store.now();
    for (final l in list.lines) {
      final label = store.labels[l.outLabel];
      if (label != null) {
        store.labels[l.outLabel] = label.copyWith(
          status: LabelStatus.inTransit,
          history: <TimelineEntry>[
            ...label.history,
            TimelineEntry(time: now, label: 'Xác nhận xuất $code'),
          ],
        );
      }
    }
    final updated =
        list.copyWith(status: PickingStatus.shipped, shippedAt: now);
    store.pickings[code] = updated;
    final order = store.orderByCode(list.orderCode);
    if (order != null && order.status == OrderStatus.approved) {
      store.replaceOrder(order.copyWith(
        status: OrderStatus.shipped,
        timeline: <TimelineEntry>[
          ...order.timeline,
          TimelineEntry(time: now, label: 'Kho đã xuất hàng ($code)'),
        ],
      ));
    }
    return MockReply.ok(updated.toJson());
  }

  // ----------------------------------------------------------------- label

  ApiResponse _label(MockUser user, String raw) {
    final code = raw.trim().toUpperCase();
    final label = store.labels[code];
    if (label == null) return MockReply.notFound('tem $code');
    if (user.role == UserRole.retailer && label.orderCode.isNotEmpty) {
      final order = store.orderByCode(label.orderCode);
      if (order != null && order.retailerCode != user.retailerCode) {
        return MockReply.forbidden(
          'Tem không thuộc đơn của bạn: $code thuộc đơn ${order.code} (${order.retailerName}). Không ghi nhận.',
        );
      }
    }
    return MockReply.ok(label.toJson());
  }

  // ------------------------------------------------------------- transfers

  Transfer? _transfer(String code) {
    for (final t in store.transfers) {
      if (t.code == code) return t;
    }
    return null;
  }

  ApiResponse _listTransfers(MockRequest r) {
    final status = r.queryStr('status').toLowerCase();
    final kind = r.queryStr('kind').toLowerCase();
    final list = store.transfers.where((t) {
      if (status.isNotEmpty && t.status.code.toLowerCase() != status) {
        return false;
      }
      if (kind.isNotEmpty && t.kind.code.toLowerCase() != kind) return false;
      return true;
    }).toList()
      ..sort((a, b) => (b.shippedAt ?? DateTime(2000))
          .compareTo(a.shippedAt ?? DateTime(2000)));
    return MockReply.page(list.map((t) => t.toJson()).toList());
  }

  ApiResponse _receive(String code, Map<String, dynamic> body) {
    final t = _transfer(code);
    if (t == null) return MockReply.notFound('phiếu $code');
    if (t.status != TransferStatus.inTransit) {
      return MockReply.conflict(
          'Phiếu $code không ở trạng thái đang vận chuyển.');
    }
    final scanned =
        asStrList(body['labelCodes']).map((c) => c.toUpperCase()).toSet();
    final expected = t.lines.map((l) => l.labelCode).toSet();
    final foreign = scanned.where((c) => !expected.contains(c)).toList();
    if (foreign.isNotEmpty) {
      return MockReply.conflict(
          'Tem ${foreign.first} không thuộc phiếu $code.');
    }
    final missing = expected.where((c) => !scanned.contains(c)).toList();
    if (missing.isNotEmpty) {
      return MockReply.conflict(
          'Chưa quét đủ tem: còn thiếu ${missing.join(', ')}.');
    }
    final now = store.now();
    for (final c in expected) {
      final label = store.labels[c];
      if (label == null) continue;
      store.labels[c] = label.copyWith(
        status: LabelStatus.inStock,
        warehouseName: 'Kho Thới An',
        location: 'Chờ xếp kệ',
        history: <TimelineEntry>[
          ...label.history,
          TimelineEntry(
              time: now,
              label: 'Nhận kho Thới An theo phiếu $code',
              delta: '+${label.qty}'),
        ],
      );
    }
    final updated = t.copyWith(
      status: TransferStatus.received,
      receivedAt: now,
      lines: t.lines.map((l) => l.copyWith(received: true)).toList(),
    );
    final i = store.transfers.indexWhere((x) => x.code == code);
    store.transfers[i] = updated;
    return MockReply.ok(updated.toJson());
  }
}
