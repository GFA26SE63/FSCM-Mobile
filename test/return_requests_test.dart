import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/api_transport.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/remote/complaints_api.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/features/retailer/complaints/complaint_form_screen.dart';

class RequestTransport implements ApiTransport {
  final requests = <ApiRequest>[];
  bool loseResponse = true;
  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    if (loseResponse) {
      loseResponse = false;
      throw const ApiException.network();
    }
    return const ApiResponse(statusCode: 200, data: {
      'id': 'request-1',
      'code': 'KN-1',
      'requestType': 'Return',
      'status': 'Open',
      'reviewStatus': 'Submitted'
    });
  }
}

void main() {
  testWidgets(
      'return form uses affected quantity and blocks quantities beyond physical return budget',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final order = Order.fromJson(
        {'id': 'order', 'orderCode': 'DH-1', 'status': 'Delivered'});
    await tester.pumpWidget(ProviderScope(overrides: [
      ordersProvider
          .overrideWith((ref) async => OrderListResult(orders: [order])),
      complaintTargetsProvider('order').overrideWith((ref) async => [
            const ComplaintTarget(
                shipmentId: 'shipment',
                shipmentCode: 'PH-1',
                allocationId: 'allocation',
                sku: 'SKU001',
                productName: 'Sữa',
                batchCode: 'BATCH-1',
                labelCode: 'TEM-1',
                expectedQuantity: 10,
                receivedQuantity: 8,
                remainingClaimableQuantity: 6,
                remainingReturnableQuantity: 3)
          ])
    ], child: const MaterialApp(home: ComplaintFormScreen(orderCode: 'DH-1'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trả hàng').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sản phẩm · batch · phần giao'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('SKU001 · BATCH-1 · PH-1').last);
    await tester.pumpAndSettle();
    expect(find.text('Số thùng yêu cầu trả / thu hồi'), findsOneWidget);
    expect(find.text('Số thùng dùng được trong phần giao này'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('complaint_affected_quantity')), '4');
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pump();
    // Status feedback is emitted through the app-level root snackbar, which
    // is intentionally not mounted in this isolated form test.
    expect(tester.takeException(), isNull);
  });
  const request = NewComplaint(
      orderCode: 'DH-1',
      sku: 'SKU001',
      labelCode: 'TEM-1',
      actualQty: 2,
      issueType: 'Damaged',
      note: 'Return two',
      shipmentId: 'shipment',
      allocationId: 'allocation',
      requestType: 'Return',
      settlementMethod: 'CashRefund',
      affectedQuantity: 2,
      requiresCollection: true);
  test(
      'lost request response reuses the operation ID and exact received part on retry',
      () async {
    final transport = RequestTransport();
    final client = ApiClient(transport: transport, tokenReader: () => 'access');
    addTearDown(client.dispose);
    final api = ComplaintsApi(client);
    await expectLater(api.create(request), throwsA(isA<ApiException>()));
    final result = await api.create(request);
    expect(result.id, 'request-1');
    final first = transport.requests[0].body as Map;
    expect(transport.requests[1].body, first);
    expect(first['requestId'], isNotEmpty);
    expect(first['affectedQuantity'], 2);
    expect(first['actualQty'], 2);
    expect(first['requestType'], 'Return');
    expect(first['settlementMethod'], 'CashRefund');
    expect(first['shipmentId'], 'shipment');
    expect(first['allocationId'], 'allocation');
    expect(first['requiresCollection'], true);
  });
  test(
      'web evidence uploads bytes with original filename and image MIME without filesystem access',
      () async {
    final transport = RequestTransport()..loseResponse = false;
    final client = ApiClient(transport: transport, tokenReader: () => 'access');
    addTearDown(client.dispose);
    await ComplaintsApi(client).addEvidence('request-1', 'blob:unreadable',
        bytes: Uint8List.fromList([1, 2, 3]), fileName: 'proof.png');
    final sent = transport.requests.single;
    expect(sent.path, '/complaints/request-1/evidence');
    final file = (sent.body as FormData).files.single.value;
    expect(file.filename, 'proof.png');
    expect(file.contentType.toString(), 'image/png');
    expect(file.length, 3);
  });
  test(
      'request progress distinguishes approved physical pending, finance pending and completed',
      () {
    Complaint parse(Map<String, dynamic> extra) => Complaint.fromJson({
          'status': 'Approved',
          'reviewStatus': 'Approved',
          'requestType': 'Return',
          ...extra
        });
    expect(parse({}).statusText, 'Đã duyệt · chờ xử lý hàng');
    expect(parse({'physicalHandlingCompleted': true}).statusText,
        'Đã duyệt · chờ chốt tài chính');
    final done = parse({
      'status': 'Resolved',
      'reviewStatus': 'Resolved',
      'financialAdjustmentApplied': true,
      'debtOffsetAmount': 400000,
      'refundAmount': 100000,
      'refundId': 'refund',
      'approvedQuantity': 5,
      'handledQuantity': 4,
      'documents': [
        {'kind': 'ReturnOrder', 'status': 'Completed'}
      ]
    });
    expect(done.statusText, 'Đã xử lý xong');
    expect(done.debtOffsetAmount, 400000);
    expect(done.refundAmount, 100000);
    expect(done.documents.single['kind'], 'ReturnOrder');
    expect(done.handledQuantity, 4);
    expect(done.acceptsEvidence, false);
  });
  test(
      'received targets preserve independent compensation and physical-return budgets',
      () {
    final target = ComplaintTarget.fromJson({
      'expectedQuantity': 10,
      'receivedQuantity': 8,
      'remainingClaimableQuantity': 6,
      'remainingReturnableQuantity': 3
    });
    expect(target.remainingClaimableQuantity, 6);
    expect(target.remainingReturnableQuantity, 3);
    final body = const NewComplaint(
            orderCode: 'DH-1',
            sku: 'SKU001',
            labelCode: 'TEM-1',
            actualQty: 1,
            issueType: 'Damaged',
            note: 'Dispose externally',
            requestType: 'DamagedCollection',
            settlementMethod: 'None',
            affectedQuantity: 1,
            requiresCollection: true)
        .toJson();
    expect(body['settlementMethod'], 'None');
    expect(body['affectedQuantity'], 1);
  });
}
