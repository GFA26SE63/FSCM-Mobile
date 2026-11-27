import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/core/network/graphql_client.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

final complaintsApiProvider = Provider<ComplaintsApi>(
    (ref) => ComplaintsApi(ref.watch(apiClientProvider)));

class ComplaintsApi {
  ComplaintsApi(this._client) : _graphQl = GraphQlClient(_client);

  final ApiClient _client;
  final GraphQlClient _graphQl;
  final Map<String, String> _pendingRequests = {};

  Future<List<ComplaintTarget>> targets(String orderId) async =>
      unwrapItems(await _client.get('/complaints/orders/$orderId/targets'))
          .map(ComplaintTarget.fromJson)
          .toList();

  // `entities.complaintReads` runs the same ComplaintService.ListAsync as REST
  // GET /complaints, with the caller's id and role. For a Retailer the store
  // limits it to the retailer linked to the account. The query has no filter,
  // sort or paging arguments, as the REST list has none. Only fields the app
  // reads are selected. Evidence and every write stay REST.
  static const String _listQuery = '''
    query Complaints {
      entities {
        complaintReads {
          id code orderCode sku productName expectedQuantity actualQuantity
          issueType status labelCode note createdAt response
          finalUnitPrice adjustmentAmount financialAdjustmentApplied
          resolutionType reviewStatus evidenceRequestReason requestType
          settlementMethod approvedSettlementMethod requestedQuantity
          approvedQuantity handledQuantity physicalHandlingCompleted
          debtOffsetAmount refundAmount refundId salesOrderId
          documents {
            id code kind status approvedQuantity actualQuantity completedAt
            note evidenceReference
          }
        }
      }
    }''';

  Future<List<Complaint>> list() async {
    Object? rows;
    try {
      final data =
          await _graphQl.query(_listQuery, operationName: 'Complaints');
      rows = asMap(data['entities'])['complaintReads'];
    } on ApiException catch (error) {
      if (!GraphQlClient.canFallBackToRest(error)) rethrow;
      rows = unwrapItems(await _client.get(Endpoints.complaints));
    }
    // A malformed answer is an error, not an empty list.
    if (rows is! List) {
      throw const ApiException(
          kind: ApiErrorKind.server,
          message: 'Phản hồi danh sách khiếu nại không hợp lệ.');
    }
    return asMapList(rows).map(Complaint.fromJson).toList();
  }

  Future<Complaint> create(NewComplaint request) async {
    final body = request.toJson();
    final signature = jsonEncode(body);
    body['requestId'] =
        _pendingRequests.putIfAbsent(signature, () => const Uuid().v4());
    final data = await _client.post(Endpoints.complaints, body: body);
    _pendingRequests.remove(signature);
    return Complaint.fromJson(asMap(data));
  }

  /// Adds one evidence image to an open claim (multipart form field "file").
  /// The content type must be sent explicitly: the server only accepts JPG/PNG/WebP and rejects
  /// the `application/octet-stream` that dio would otherwise use.
  Future<void> addEvidence(String complaintId, String filePath,
      {Uint8List? bytes, String? fileName}) async {
    final name = fileName ?? filePath.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap(<String, dynamic>{
      'file': bytes != null
          ? MultipartFile.fromBytes(bytes,
              filename: name, contentType: DioMediaType.parse(_imageType(name)))
          : await MultipartFile.fromFile(filePath,
              filename: name,
              contentType: DioMediaType.parse(_imageType(name))),
    });
    await _client.post('/complaints/$complaintId/evidence', body: form);
  }

  Future<List<ComplaintEvidence>> evidence(String complaintId) async =>
      unwrapItems(await _client.get('/complaints/$complaintId/evidence'))
          .map(ComplaintEvidence.fromJson)
          .toList();

  /// Removes one evidence image of an undecided claim so the retailer can pick another.
  Future<void> removeEvidence(String complaintId, String evidenceId) async =>
      _client.delete('/complaints/$complaintId/evidence/$evidenceId');

  /// Retailer withdraws a claim that has not been decided yet.
  Future<void> cancel(String complaintId) async =>
      _client.post('/complaints/$complaintId/cancel');

  static String _imageType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<List<String>> receivedLabels(String orderId) async {
    final data = asMap(
      await _client.get(Endpoints.shipmentDeliveryView(orderId)),
    );
    final labels = <String>{};
    for (final shipment in asMapList(data['shipments'])) {
      final receipt = asMap(shipment['receipt']);
      labels.addAll(asStrList(receipt['qrCodes']));
    }
    return labels.toList()..sort();
  }
}
