import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

enum WarehouseOperation {
  factoryReceipt('Nhập từ nhà máy'),
  transferReceipt('Nhập luân chuyển'),
  orderIssue('Xuất bán hàng'),
  transferIssue('Xuất luân chuyển');

  const WarehouseOperation(this.title);
  final String title;
  bool includes(Map<String, dynamic> d) => switch (this) {
        factoryReceipt => d['reason'] == 'Factory' && d['kind'] == 'Receipt',
        transferReceipt => d['reason'] == 'Transfer' && d['kind'] == 'Receipt',
        orderIssue => d['reason'] == 'Order',
        transferIssue => d['reason'] == 'Transfer' && d['kind'] != 'Receipt',
      };
}

class WarehouseWork {
  WarehouseWork(Map<String, dynamic> json)
      : document = asMap(json['document']),
        lines = asMapList(json['lines']),
        cartons = asMapList(json['cartons']);
  final Map<String, dynamic> document;
  final List<Map<String, dynamic>> lines, cartons;
  String get id => asStr(document['id']);
  int get version => asInt(document['version']);
  bool get factory => document['reason'] == 'Factory';
  bool get pending => const ['Open', 'Prepared'].contains(document['status']);
  bool get historic =>
      document['kind'] != 'Request' &&
      document['kind'] != 'Picking' &&
      !pending;
}

final warehouseDocumentsApiProvider = Provider((ref) {
  ref.watch(currentUserProvider);
  return WarehouseDocumentsApi(ref.watch(apiClientProvider));
});
final warehouseDocumentsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(warehouseDocumentsApiProvider).list());
final factoryArrivalsProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(warehouseDocumentsApiProvider).arrivals());
final warehouseDocumentProvider = FutureProvider.autoDispose
    .family<WarehouseWork, String>(
        (ref, id) => ref.watch(warehouseDocumentsApiProvider).get(id));

class WarehouseDocumentsApi {
  WarehouseDocumentsApi(this.client);
  final ApiClient client;
  static const base = '/warehouse-documents';
  Future<List<WarehouseWork>> list() async =>
      asMapList(await client.get(base)).map(WarehouseWork.new).toList();
  Future<List<Map<String, dynamic>>> arrivals() async =>
      asMapList(await client.get('$base/factory-pending'));
  Future<WarehouseWork> get(String id) async =>
      WarehouseWork(asMap(await client.get('$base/$id')));
  Future<WarehouseWork> prepare(String code) async => WarehouseWork(asMap(
      await client.post('$base/factory-receipts/from-pallet',
          body: {'palletCode': code})));
  Future<WarehouseWork> child(String id) async =>
      WarehouseWork(asMap(await client.post('$base/$id/create-document',
          headers: {'Idempotency-Key': 'mobile-child-$id'})));
  Future<Map<String, dynamic>> scanPallet(
          WarehouseWork work, String code) async =>
      asMap(await client.post('$base/${work.id}/pallet-scans', body: {
        'code': code,
        'expectedVersion': work.version,
        'source': 'Camera'
      }));
  Future<WarehouseWork> confirmPallet(
          WarehouseWork work,
          Map<String, dynamic> scan,
          List<Map<String, dynamic>> cartons) async =>
      WarehouseWork(
          asMap(await client.post('$base/${work.id}/receive-pallet', body: {
        'palletCode': scan['palletCode'],
        'scanId': scan['id'],
        'expectedVersion': scan['documentVersion'],
        'cartons': cartons,
      })));
  Future<WarehouseWork> scanCarton(WarehouseWork work, String code) async =>
      WarehouseWork(asMap(await client.post('$base/${work.id}/scans',
          body: {'cartonId': code, 'expectedVersion': work.version})));
  Future<WarehouseWork> post(WarehouseWork work) async =>
      WarehouseWork(asMap(await client.post('$base/${work.id}/post',
          body: {'expectedVersion': work.version})));
}
