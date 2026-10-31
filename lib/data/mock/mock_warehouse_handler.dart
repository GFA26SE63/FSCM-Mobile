import 'package:fscm_mobile/core/auth/user_role.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/mock/mock_http.dart';
import 'package:fscm_mobile/data/mock/mock_store.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/models/timeline_entry.dart';
import 'package:fscm_mobile/data/models/transfer.dart';

/// `/picking-lists`, `/shipments`, `/qr-labels`, `/transfers`.
class MockWarehouseHandler extends MockHandler {
  MockWarehouseHandler(super.store);

  @override
  ApiResponse? handle(MockRequest r) {
    final user = r.user;
    if (user == null) return null;

    if (r.matches('GET', '/picking-lists')) return _listSheets(r);
    if (r.matches('GET', '/picking-lists/*')) {
      final sheet = store.pickingSheets[r.segments[1]];
      return sheet == null
          ? MockReply.notFound('phiếu soạn ${r.segments[1]}')
          : MockReply.ok(sheet);
    }
    if (r.matches('POST', '/picking-lists/*/scans')) {
      return _scan(r, r.segments[1]);
    }
    if (r.matches('POST', '/picking-lists/*/complete')) {
      return _complete(r.segments[1], r.body);
    }

    if (r.matches('GET', '/shipments')) return _listShipments(r);
    if (r.matches('GET', '/shipments/orders/*/readiness')) {
      return _readiness(r.segments[2]);
    }
    if (r.matches('POST', '/shipments/*/issue')) {
      return _issue(r.segments[1], r.body);
    }

    if (r.matches('GET', '/qr-labels/*')) return _label(user, r.segments[1]);

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

  // ----------------------------------------------------------- run picking

  ApiResponse _listSheets(MockRequest r) {
    final status = r.queryStr('status').toLowerCase();
    final sheets = store.pickingSheets.values
        .where((sheet) =>
            status.isEmpty || asStr(sheet['status']).toLowerCase() == status)
        .toList()
      ..sort((a, b) => asStr(b['issuedAt']).compareTo(asStr(a['issuedAt'])));
    return MockReply.page(sheets);
  }

  /// F44 the way the server does it: the batch is fixed by the gather, the
  /// quantity is spent on the splits the caller named, and the whole call is
  /// keyed by an idempotency key so a retry costs nothing.
  ApiResponse _scan(MockRequest r, String code) {
    final sheet = store.pickingSheets[code];
    if (sheet == null) return MockReply.notFound('phiếu soạn $code');

    final key = r.idempotencyKey;
    if (key.isNotEmpty && store.scanKeys.contains(key)) {
      // Already applied once. The real server replies with the sheet untouched
      // rather than taking the cartons a second time.
      return MockReply.ok(sheet);
    }

    final status = asStr(sheet['status']);
    if (status == 'Ready' || status == 'NeedsHandling') {
      return MockReply.conflict('Phiếu đã đóng, không nhận thêm lượt quét.');
    }
    final version = asInt(sheet['version']);
    if (version != asInt(r.body['expectedPickingVersion'])) {
      return MockReply.conflict(
          'Phiếu đang ở version $version; tải lại rồi quét lại.');
    }

    final qr = asStr(r.body['qrCode']).trim().toUpperCase();
    final label = store.labels[qr];
    if (label == null) return MockReply.notFound('tem $qr');
    if (label.status != LabelStatus.inStock) {
      return MockReply.conflict(
          'Tem $qr đang ở trạng thái "${label.status.label}".');
    }

    final requested = asMapList(r.body['splits']);
    if (requested.isEmpty) {
      return MockReply.invalid('Phải có ít nhất một dòng chia về đơn.');
    }

    Map<String, dynamic>? gather;
    for (final candidate in asMapList(sheet['gathers'])) {
      if (asStr(candidate['sku']) == label.sku &&
          asStr(candidate['batchCode']) == label.batchCode) {
        gather = candidate;
        break;
      }
    }
    if (gather == null) {
      return MockReply.conflict(
          'Tem $qr thuộc ${label.sku} · ${label.batchCode}, không nằm trong phương án đã duyệt của phiếu này.');
    }

    final total =
        requested.fold<double>(0, (sum, s) => sum + asDouble(s['quantity']));
    if (total <= 0) return MockReply.invalid('Số lượng phải lớn hơn 0.');
    if (total > label.qty) {
      return MockReply.invalid('Tem $qr chỉ còn ${label.qty} thùng.');
    }
    final gatherLeft = asDouble(gather['remainingQuantity']);
    if (total > gatherLeft) {
      return MockReply.conflict(
          'Vượt lượng còn lại của lượt lấy ($gatherLeft thùng).');
    }

    final splits = asMapList(gather['splits']);
    for (final want in requested) {
      final id = asStr(want['allocationRunAllocationId']);
      Map<String, dynamic>? target;
      for (final candidate in splits) {
        if (asStr(candidate['allocationRunAllocationId']) == id) {
          target = candidate;
          break;
        }
      }
      if (target == null) {
        return MockReply.conflict('Dòng chia $id không thuộc lượt lấy này.');
      }
      final take = asDouble(want['quantity']);
      if (take > asDouble(target['remainingQuantity'])) {
        return MockReply.conflict(
            'Đơn ${asStr(target['orderCode'])} không cần thêm ${take.round()} thùng.');
      }
      target['pickedQuantity'] = asDouble(target['pickedQuantity']) + take;
      target['remainingQuantity'] = asDouble(target['requiredQuantity']) -
          asDouble(target['pickedQuantity']);
    }

    gather['pickedQuantity'] = asDouble(gather['pickedQuantity']) + total;
    gather['remainingQuantity'] = asDouble(gather['requiredQuantity']) -
        asDouble(gather['pickedQuantity']);
    gather['status'] =
        asDouble(gather['remainingQuantity']) <= 0.0005 ? 'Picked' : 'Pending';

    final taken = total.round();
    final left = label.qty - taken;
    store.labels[qr] = label.copyWith(
      qty: left,
      status: left <= 0 ? LabelStatus.picked : LabelStatus.inStock,
      pickingCode: code,
      history: <TimelineEntry>[
        ...label.history,
        TimelineEntry(
            time: store.now(),
            label: 'Lấy $taken thùng cho phiếu $code',
            delta: '-$taken'),
      ],
    );

    sheet['status'] = 'Picking';
    sheet['startedAt'] ??= store.now().toIso8601String();
    sheet['version'] = version + 1;
    if (key.isNotEmpty) store.scanKeys.add(key);
    return MockReply.ok(sheet);
  }

  /// Closes this warehouse's portion. Nothing leaves and no stock moves here;
  /// that is the issue step, deliberately kept apart from this one.
  ApiResponse _complete(String code, Map<String, dynamic> body) {
    final sheet = store.pickingSheets[code];
    if (sheet == null) return MockReply.notFound('phiếu soạn $code');
    final version = asInt(sheet['version']);
    if (version != asInt(body['expectedPickingVersion'])) {
      return MockReply.conflict(
          'Phiếu đang ở version $version; tải lại rồi thử lại.');
    }

    final exceptionType = asStrOrNull(body['exceptionType']);
    if (exceptionType == null) {
      final short = asMapList(sheet['gathers'])
          .where((g) => asDouble(g['remainingQuantity']) > 0.0005)
          .length;
      if (short > 0) {
        return MockReply.conflict(
            'Còn $short lượt lấy chưa đủ. Quét đủ hoặc báo ngoại lệ.');
      }
    }

    sheet['status'] = exceptionType == null ? 'Ready' : 'NeedsHandling';
    sheet['exceptionType'] = exceptionType;
    sheet['exceptionNote'] = asStrOrNull(body['note']);
    sheet['completedAt'] = store.now().toIso8601String();
    sheet['version'] = version + 1;

    // The order parts follow the sheet. A clean close makes what was waiting
    // ready; an exception holds every part that has not already left, not just
    // the ones still waiting - a part sitting Ready on the dock is exactly what
    // has to be stopped, which is the whole of "no partial delivery".
    for (final shipment in store.shipments.values) {
      if (asStr(shipment['pickingCode']) != code) continue;
      final status = asStr(shipment['status']);
      if (status == 'Issued' ||
          status == 'Delivering' ||
          status == 'Received') {
        continue;
      }
      if (exceptionType == null) {
        if (status != 'WaitingToPick') continue;
        shipment['status'] = 'Ready';
        shipment['exceptionReason'] = null;
      } else {
        shipment['status'] = 'Exception';
        shipment['exceptionReason'] =
            asStrOrNull(body['note']) ?? exceptionType;
      }
      shipment['version'] = asInt(shipment['version']) + 1;
    }
    return MockReply.ok(sheet);
  }

  // ------------------------------------------------------ readiness, issue

  ApiResponse _listShipments(MockRequest r) {
    final orderId = r.queryStr('orderId');
    final status = r.queryStr('status').toLowerCase();
    final list = store.shipments.values
        .where((s) => orderId.isEmpty || asStr(s['orderId']) == orderId)
        .where(
            (s) => status.isEmpty || asStr(s['status']).toLowerCase() == status)
        .toList();
    return MockReply.page(list);
  }

  /// F93. The verdict is taken for the whole order, never per warehouse: one
  /// part short or in exception holds every other part of the order too.
  ApiResponse _readiness(String orderId) {
    final parts = store.shipments.values
        .where((s) => asStr(s['orderId']) == orderId)
        .toList();
    if (parts.isEmpty) {
      return MockReply.notFound('phiếu giao của đơn $orderId');
    }

    final reasons = <String>[];
    var hasException = false;
    for (final part in parts) {
      switch (asStr(part['status'])) {
        case 'Exception':
          hasException = true;
          reasons.add('Kho ${asStr(part['warehouseCode'])}: '
              '${asStr(part['exceptionReason'])}');
        case 'WaitingToPick':
          reasons.add('Kho ${asStr(part['warehouseCode'])} chưa soạn đủ.');
      }
    }

    // Only a prepaid order is gated on payment, matching the server: a credit
    // order leaves and is collected afterwards.
    final orderCode = asStr(parts.first['orderCode']);
    final order = store.orderByCode(orderCode);
    final prepaid = order?.payment == PaymentMethod.prepaid;
    final paymentSettled = !prepaid || _isCollected(orderCode);
    if (!paymentSettled) reasons.add('Đơn trả trước chưa thanh toán đủ.');

    return MockReply.ok(<String, dynamic>{
      'salesOrderId': orderId,
      'orderCode': orderCode,
      'isReady': reasons.isEmpty,
      'paymentSettled': paymentSettled,
      'hasException': hasException,
      'blockingReasons': reasons,
      'parts': <Map<String, dynamic>>[
        for (final part in parts)
          <String, dynamic>{
            'shipmentId': asStr(part['id']),
            'shipmentCode': asStr(part['shipmentCode']),
            'warehouseId': asStr(part['warehouseId']),
            'warehouseCode': asStr(part['warehouseCode']),
            'status': asStr(part['status']),
            'exceptionReason': asStrOrNull(part['exceptionReason']),
          },
      ],
    });
  }

  bool _isCollected(String orderCode) {
    for (final receivable in store.receivables) {
      if (receivable.orderCode != orderCode) continue;
      return receivable.status == ReceivableStatus.paid;
    }
    return true;
  }

  /// F96. Stock falls here and nowhere else, and only when the whole order is
  /// ready. Calling it again returns the part unchanged.
  ApiResponse _issue(String id, Map<String, dynamic> body) {
    final shipment = store.shipments[id];
    if (shipment == null) return MockReply.notFound('phiếu giao $id');
    if (asStr(shipment['status']) == 'Issued') return MockReply.ok(shipment);

    final readiness = asMap(_readiness(asStr(shipment['orderId'])).data);
    if (!asBool(readiness['isReady'])) {
      return MockReply.conflict('Đơn chưa được xuất: '
          '${asStrList(readiness['blockingReasons']).join(' ')}');
    }
    final version = asInt(shipment['version']);
    if (version != asInt(body['expectedVersion'])) {
      return MockReply.conflict(
          'Phiếu giao đang ở version $version; tải lại rồi thử lại.');
    }

    shipment['status'] = 'Issued';
    shipment['issuedAt'] = store.now().toIso8601String();
    shipment['version'] = version + 1;
    return MockReply.ok(shipment);
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
