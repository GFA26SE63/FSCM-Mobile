import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/core/network/endpoints.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';

final complaintsApiProvider = Provider<ComplaintsApi>(
    (ref) => ComplaintsApi(ref.watch(apiClientProvider)));

class ComplaintsApi {
  ComplaintsApi(this._client);

  final ApiClient _client;

  Future<List<ComplaintTarget>> targets(String orderId) async =>
      unwrapItems(await _client.get('/complaints/orders/$orderId/targets'))
          .map(ComplaintTarget.fromJson)
          .toList();

  Future<List<Complaint>> list() async {
    final data = await _client.get(Endpoints.complaints);
    return unwrapItems(data).map(Complaint.fromJson).toList();
  }

  Future<Complaint> create(NewComplaint request) async {
    final data =
        await _client.post(Endpoints.complaints, body: request.toJson());
    return Complaint.fromJson(asMap(data));
  }

  /// Adds one evidence image to an open claim (multipart form field "file").
  /// The content type must be sent explicitly: the server only accepts JPG/PNG/WebP and rejects
  /// the `application/octet-stream` that dio would otherwise use.
  Future<void> addEvidence(String complaintId, String filePath) async {
    final form = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath,
          filename: filePath.split(RegExp(r'[\\/]')).last,
          contentType: DioMediaType.parse(_imageType(filePath))),
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
