import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'warehouse_documents_api.dart';

final warehouseOperationErrorProvider =
    StateProvider.autoDispose<String?>((ref) => null);

class WarehouseOperationsScreen extends StatelessWidget {
  const WarehouseOperationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nhập · Xuất kho')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Chọn nghiệp vụ để mở chứng từ và quét hàng thực tế.'),
          for (final operation in WarehouseOperation.values)
            Card(
                child: ListTile(
                    leading: Icon(operation.index < 2
                        ? Icons.move_to_inbox
                        : Icons.outbox),
                    title: Text(operation.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/wk/documents/${operation.name}'))),
        ]),
      );
}

final warehouseHistoryProvider = StateProvider.autoDispose
    .family<bool, WarehouseOperation>((ref, operation) => false);

class WarehouseDocumentsScreen extends ConsumerWidget {
  const WarehouseDocumentsScreen(
      {super.key, required this.operation, this.initialHistory = false});
  final bool initialHistory;
  final WarehouseOperation operation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(warehouseHistoryProvider(operation)) || initialHistory;
    final operationError = ref.watch(warehouseOperationErrorProvider);
    final user = ref.watch(currentUserProvider);
    final scope = user?.warehouseIds ?? <String>[];
    String warehouseName(Object? id) =>
        user?.warehouseLabels.where((w) => w.id == id).firstOrNull?.name ??
        asStr(id);
    final value = ref.watch(warehouseDocumentsProvider);
    final arrivals = operation == WarehouseOperation.factoryReceipt
        ? ref.watch(factoryArrivalsProvider)
        : null;
    return Scaffold(
        appBar: AppBar(title: Text(operation.title)),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(warehouseDocumentsProvider);
            ref.invalidate(factoryArrivalsProvider);
            await ref.read(warehouseDocumentsProvider.future);
          },
          child: AsyncBody(
              value: value,
              onRetry: () => ref.invalidate(warehouseDocumentsProvider),
              builder: (all) {
                final works = all
                    .where((w) =>
                        operation.includes(w.document) &&
                        (w.document['kind'] != 'Request' ||
                            !all.any((child) =>
                                child.document['sourceDocumentId'] == w.id)) &&
                        scope.contains(w.document['warehouseId']) &&
                        (history ? w.historic : w.pending))
                    .toList();
                final incoming = !history &&
                        operation == WarehouseOperation.transferReceipt
                    ? all
                        .where((w) =>
                            w.document['reason'] == 'Transfer' &&
                            w.document['kind'] == 'Issue' &&
                            w.document['status'] == 'Posted' &&
                            scope.contains(
                                w.document['destinationWarehouseId']) &&
                            !all.any(
                                (r) => r.document['sourceDocumentId'] == w.id))
                        .toList()
                    : <WarehouseWork>[];
                return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!initialHistory)
                        SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false, label: Text('Cần xử lý')),
                              ButtonSegment(value: true, label: Text('Lịch sử'))
                            ],
                            selected: {
                              history
                            },
                            onSelectionChanged: (v) => ref
                                .read(warehouseHistoryProvider(operation)
                                    .notifier)
                                .state = v.single),
                      if (history)
                        const Text(
                            'Chứng từ đã hoàn tất chỉ dùng để xem; không quét lại.'),
                      if (operationError != null)
                        Text(operationError,
                            style: const TextStyle(color: Colors.red)),
                      if (arrivals != null && !history) ...[
                        const Text('Hàng nhà máy đã xuất về kho của bạn',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        AsyncBody(
                            value: arrivals,
                            onRetry: () =>
                                ref.invalidate(factoryArrivalsProvider),
                            builder: (rows) => Column(children: [
                                  if (rows.isEmpty)
                                    const ListTile(
                                        title:
                                            Text('Không có pallet chờ nhận.')),
                                  for (final p in rows)
                                    Card(
                                        child: ListTile(
                                            title: Text(asStr(p['palletCode'])),
                                            subtitle: Text(
                                                '${p['sku']} · ${p['cartonCount']} thùng\nKho nhận: ${warehouseName(p['destinationWarehouseId'])} (cố định)'),
                                            trailing:
                                                const Icon(Icons.chevron_right),
                                            onTap: () async {
                                              try {
                                                final w = await ref
                                                    .read(
                                                        warehouseDocumentsApiProvider)
                                                    .prepare(
                                                        asStr(p['palletCode']));
                                                ref.invalidate(
                                                    warehouseDocumentsProvider);
                                                if (context.mounted) {
                                                  unawaited(context.push(
                                                      '/wk/document/${w.id}'));
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ref
                                                          .read(
                                                              warehouseOperationErrorProvider
                                                                  .notifier)
                                                          .state =
                                                      ApiException.describe(e);
                                                }
                                              }
                                            })),
                                ])),
                      ],
                      for (final issue in incoming)
                        Card(
                            color: Colors.blue.shade50,
                            child: ListTile(
                                leading: const Icon(Icons.move_to_inbox,
                                    color: Colors.blue),
                                title: Text(
                                    'Hàng đang đến: ${issue.document['code']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Từ ${warehouseName(issue.document['warehouseId'])} · Đã xuất ${issue.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0))} carton\nBấm để mở phiếu nhập & bắt đầu quét carton'),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                    '/wk/document/${issue.id}?mode=transferReceipt'))),
                      const SizedBox(height: 16),
                      const Text('Chứng từ kho',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      if (works.isEmpty)
                        const ListTile(
                            title: Text(
                                'Chưa có chứng từ trong phạm vi kho của bạn.')),
                      for (final w in works)
                        Card(
                            child: ListTile(
                                title: Text(asStr(w.document['code'])),
                                subtitle: Text(
                                    '${documentTypeTitle(w.document)} · ${warehouseName(w.document['warehouseId'])}${w.document['destinationWarehouseId'] != null && w.document['destinationWarehouseId'] != w.document['warehouseId'] ? ' → ${warehouseName(w.document['destinationWarehouseId'])}' : ''} · ${warehouseStatus(w.document['status'])} · ${w.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0))} carton'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                    '/wk/document/${w.id}?mode=${operation.name}'))),
                    ]);
              }),
        ));
  }
}

String documentTypeTitle(Map<String, dynamic> d) {
  final kind = d['kind'];
  final reason = d['reason'];
  if (kind == 'Request' && reason == 'Transfer') return 'Lệnh điều chuyển kho';
  if (kind == 'Issue' && reason == 'Transfer') return 'Phiếu xuất luân chuyển';
  if (kind == 'Receipt' && reason == 'Transfer') return 'Phiếu nhập luân chuyển';
  if (kind == 'Request' && reason == 'Order') return 'Lệnh xuất bán hàng';
  if (kind == 'Issue' && reason == 'Order') return 'Phiếu xuất bán hàng';
  if (kind == 'Receipt' && reason == 'Factory') return 'Phiếu nhập từ nhà máy';
  if (kind == 'Request') return 'Lệnh xuất / điều chuyển';
  if (kind == 'Issue') return 'Phiếu xuất kho';
  if (kind == 'Receipt') return 'Phiếu nhập kho';
  if (kind == 'Picking') return 'Phiếu soạn hàng';
  return asStr(kind);
}

String warehouseStatus(Object? value) => switch (value) {
      'Open' => 'Chờ thực hiện',
      'Prepared' => 'Đã soạn đủ',
      'Posted' => 'Đã ghi sổ',
      'Executed' => 'Đã thực hiện',
      'Fulfilled' => 'Đã thực hiện',
      'Cancelled' => 'Đã hủy',
      _ => asStr(value),
    };

String receiptDispositionLabel(Object? value) => switch (value) {
      'Accepted' => 'Đạt',
      'Damaged' => 'Hỏng — cách ly',
      'Missing' => 'Thiếu',
      _ => asStr(value),
    };

class WarehouseDocumentScreen extends ConsumerStatefulWidget {
  const WarehouseDocumentScreen({
    super.key,
    required this.id,
    this.mode,
    this.autoScan = false,
  });
  final String? mode;
  final String id;
  final bool autoScan;
  @override
  ConsumerState<WarehouseDocumentScreen> createState() =>
      _WarehouseDocumentScreenState();
}

class _WarehouseDocumentScreenState
    extends ConsumerState<WarehouseDocumentScreen> {
  bool busy = false, camera = false;
  String? error, notice;
  Map<String, dynamic>? scan;
  List<Map<String, dynamic>> inspection = [];
  List<Map<String, dynamic>> reports = [], scanHistory = [];
  @override
  void initState() {
    super.initState();
    camera = widget.autoScan;
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final api = ref.read(warehouseDocumentsApiProvider);
      final r = asMapList(await api.client
          .get('${WarehouseDocumentsApi.base}/${widget.id}/receipt-reports'));
      final s = asMapList(await api.client
          .get('${WarehouseDocumentsApi.base}/${widget.id}/pallet-scans'));
      if (mounted) {
        setState(() {
          reports = r;
          scanHistory = s;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = ApiException.describe(e));
    }
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      camera = false;
      error = null;
      notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = ApiException.describe(e));
    } finally {
      if (mounted) {
        ref.invalidate(warehouseDocumentProvider(widget.id));
        ref.invalidate(warehouseDocumentsProvider);
        ref.invalidate(factoryArrivalsProvider);
        await loadHistory();
        if (mounted) setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(warehouseDocumentProvider(widget.id));
    final user = ref.watch(currentUserProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Chứng từ kho')),
        body: AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(warehouseDocumentProvider(widget.id)),
            builder: (w) {
              final d = w.document;
              final own =
                  user?.warehouseIds.contains(d['warehouseId']) ?? false;
              final incoming = widget.mode == 'transferReceipt' &&
                  d['kind'] == 'Issue' &&
                  d['reason'] == 'Transfer' &&
                  d['status'] == 'Posted' &&
                  (user?.warehouseIds.contains(d['destinationWarehouseId']) ??
                      false);
              final request =
                  d['kind'] == 'Request' && d['status'] == 'Open' && own;
              final editable = own && d['status'] == 'Open';
              final requiredQuantity = w.lines
                  .fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0));
              final scanned =
                  w.cartons.where((c) => c['scannedAt'] != null).length;
              final canPost = !busy &&
                  own &&
                  (d['status'] == 'Open' || d['status'] == 'Prepared') &&
                  (w.factory
                      ? reports.isNotEmpty
                      : w.cartons.isNotEmpty && scanned == requiredQuantity);
              final valid = scan != null &&
                  inspection.isNotEmpty &&
                  inspection.every((c) =>
                      c['disposition'] == 'Accepted' ||
                      (asStr(c['reason']).trim().isNotEmpty &&
                          (c['disposition'] == 'Missing' ||
                              c['disposition'] == 'Damaged' &&
                                  asStr(c['quarantineLocation'])
                                      .trim()
                                      .isNotEmpty)));
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text(asStr(d['code']),
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                    '${documentTypeTitle(d)} · ${warehouseStatus(d['status'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (d['sourceDocumentId'] != null)
                  Text('Theo chứng từ nguồn: ${asStr(d['sourceDocumentId'])}'),
                Text(
                    'Kho phụ trách: ${user?.warehouseLabels.where((s) => s.id == d['warehouseId']).map((s) => s.name).firstOrNull ?? d['warehouseId']}'),
                if (d['destinationWarehouseId'] != null &&
                    d['destinationWarehouseId'] != d['warehouseId'])
                  Text(
                      'Kho đích: ${user?.warehouseLabels.where((s) => s.id == d['destinationWarehouseId']).map((s) => s.name).firstOrNull ?? d['destinationWarehouseId']}'),
                Text('Ngày lập: ${d['createdAt']}'),
                if (d['postedAt'] != null) Text('Ghi sổ: ${d['postedAt']}'),
                if (d['note'] != null && asStr(d['note']).isNotEmpty)
                  Text('Ghi chú: ${asStr(d['note'])}'),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(notice!, style: const TextStyle(color: Colors.green)),
                  ),
                if (incoming)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      'Lô hàng này đã được kho gửi xuất đi. Nhấn "Bắt đầu kiểm nhận & quét QR" để mở phiếu nhập kho đích và quét từng carton.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                if (request && d['reason'] == 'Transfer')
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'Đây là Lệnh điều chuyển kho do Admin phát hành. Nhấn "Bắt đầu xuất luân chuyển & quét QR" để bắt đầu soạn và quét carton xuất kho.',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ),
                if (request && d['reason'] == 'Order')
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'Đây là Lệnh xuất bán hàng do Admin phát hành từ đơn hàng của Đại lý. Nhấn "Bắt đầu xuất kho & quét QR" để mở phiếu xuất và quét từng carton.',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ),
                if (d['status'] == 'Posted')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                        'Phiếu đã ghi sổ. Đây là lịch sử xuất/nhập, không quét lại.'),
                  ),
                if (busy) const LinearProgressIndicator(),
                for (final l in w.lines)
                  Card(
                      child: ListTile(
                          title: Text('${l['sku']} · ${l['productName']}'),
                          subtitle: Text(
                              '${l['batchCode'] ?? l['sourceLotCode'] ?? ''}\nHSD: ${l['expirationDate']} · ${l['quantity']} thùng'))),
                if (request || incoming)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FilledButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: busy
                            ? null
                            : () => act(() async {
                                  final child = await ref
                                      .read(warehouseDocumentsApiProvider)
                                      .child(w.id);
                                  if (context.mounted) {
                                    context.pushReplacement(
                                        '/wk/document/${child.id}?mode=${widget.mode ?? ''}&scan=1');
                                  }
                                }),
                        label: Text(incoming
                            ? 'Bắt đầu kiểm nhận & quét QR'
                            : d['reason'] == 'Transfer'
                                ? 'Bắt đầu xuất luân chuyển & quét QR'
                                : 'Bắt đầu xuất kho & quét QR')),
                  ),
                if (editable &&
                    (d['kind'] == 'Receipt' ||
                        (d['kind'] == 'Picking' || d['kind'] == 'Issue')) &&
                    scan == null)
                  FilledButton.icon(
                      onPressed:
                          busy ? null : () => setState(() => camera = !camera),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(w.factory
                          ? 'Quét pallet thực tế'
                          : 'Quét carton thực tế')),
                if (camera && !busy)
                  QrScanView(
                      allowManual: false,
                      hint: w.factory
                          ? 'Quét đúng QR pallet trên phiếu'
                          : 'Quét QR từng thùng',
                      onCode: (code) => act(() async {
                            final api = ref.read(warehouseDocumentsApiProvider);
                            if (w.factory) {
                              final result = await api.scanPallet(w, code);
                              if (!mounted) return;
                              setState(() {
                                scan = result;
                                inspection = asMapList(
                                        asMap(result['manifest'])['cartons'])
                                    .map((c) => <String, dynamic>{
                                          'cartonCode': c['code'],
                                          'disposition': '',
                                          'reason': '',
                                          'quarantineLocation': ''
                                        })
                                    .toList();
                                notice =
                                    'Đã quét đúng pallet. Chưa cộng tồn; hãy kiểm đếm và xác nhận.';
                              });
                            } else {
                              await api.scanCarton(w, code);
                              if (mounted) {
                                setState(() => notice =
                                    'Đã ghi nhận thùng. Chờ xác nhận ghi sổ.');
                              }
                            }
                          })),
                if (scan != null) ...[
                  Card(
                    color: Colors.blue.shade50,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pallet: ${scan!['palletCode']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              'Đã quét lúc: ${scan!['scannedAt']} · Tổng ${inspection.length} thùng'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.done_all, size: 18),
                                label: const Text('Đánh dấu tất cả Đạt'),
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          for (final c in inspection) {
                                            if (c['disposition'] == '') {
                                              c['disposition'] = 'Accepted';
                                            }
                                          }
                                        }),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.restart_alt, size: 18),
                                label: const Text('Đặt lại chưa kiểm'),
                                onPressed: busy
                                    ? null
                                    : () => setState(() {
                                          for (final c in inspection) {
                                            c['disposition'] = '';
                                            c['reason'] = '';
                                            c['quarantineLocation'] = '';
                                          }
                                        }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tiến độ kiểm: Đạt: ${inspection.where((c) => c['disposition'] == 'Accepted').length} · Hỏng/Cách ly: ${inspection.where((c) => c['disposition'] == 'Damaged').length} · Thiếu: ${inspection.where((c) => c['disposition'] == 'Missing').length} / ${inspection.length} thùng',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final c in inspection)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(asStr(c['cartonCode'])),
                                  DropdownButtonFormField<String>(
                                      value: asStr(c['disposition']),
                                      items: const [
                                        DropdownMenuItem(
                                            value: '',
                                            child: Text('Chưa kiểm')),
                                        DropdownMenuItem(
                                            value: 'Accepted',
                                            child: Text('Đạt')),
                                        DropdownMenuItem(
                                            value: 'Damaged',
                                            child: Text('Hỏng · cách ly')),
                                        DropdownMenuItem(
                                            value: 'Missing',
                                            child: Text('Thiếu'))
                                      ],
                                      onChanged: busy
                                          ? null
                                          : (v) => setState(
                                              () => c['disposition'] = v)),
                                  if (c['disposition'] == 'Damaged' ||
                                      c['disposition'] == 'Missing')
                                    TextFormField(
                                        initialValue: asStr(c['reason']),
                                        enabled: !busy,
                                        decoration: const InputDecoration(
                                            labelText: 'Lý do (bắt buộc)'),
                                        onChanged: (v) =>
                                            setState(() => c['reason'] = v)),
                                  if (c['disposition'] == 'Damaged')
                                    TextFormField(
                                        initialValue:
                                            asStr(c['quarantineLocation']),
                                        enabled: !busy,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Vị trí cách ly (bắt buộc)'),
                                        onChanged: (v) => setState(
                                            () => c['quarantineLocation'] = v)),
                                ]))),
                  FilledButton(
                      onPressed: busy || !valid
                          ? null
                          : () => act(() async {
                                await ref
                                    .read(warehouseDocumentsApiProvider)
                                    .confirmPallet(w, scan!, inspection);
                                if (mounted) {
                                  setState(() {
                                    scan = null;
                                    inspection = [];
                                    notice =
                                        'Đã nhận pallet. Chỉ thùng đạt được cộng tồn.';
                                  });
                                }
                              }),
                      child: const Text('Xác nhận kiểm đếm và nhập pallet')),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                scan = null;
                                inspection = [];
                              }),
                      child: const Text('Hủy kiểm đếm chưa xác nhận')),
                ],
                if (!w.factory)
                  Text('Đã quét $scanned / $requiredQuantity thùng'),
                for (final c in w.cartons)
                  ListTile(
                      title: Text(asStr(c['cartonId'])),
                      subtitle: Text(c['scannedAt'] == null
                          ? 'Chưa quét'
                          : 'Đã quét: ${c['scannedAt']}')),
                if (own && w.pending && !canPost && scan == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      w.factory
                          ? '⚠️ Cần quét pallet và xác nhận kiểm đếm trước khi ghi sổ phiếu.'
                          : '⚠️ Cần quét đủ $requiredQuantity thùng (đã quét $scanned/$requiredQuantity) để ghi sổ.',
                      style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                if (own &&
                    w.pending &&
                    (d['kind'] == 'Receipt' ||
                        (d['kind'] == 'Picking' || d['kind'] == 'Issue')))
                  FilledButton(
                      onPressed: canPost && scan == null
                          ? () => act(() async {
                                final result = await ref
                                    .read(warehouseDocumentsApiProvider)
                                    .post(w);
                                if (context.mounted && result.id != w.id) {
                                  context.pushReplacement(
                                      '/wk/document/${result.id}?mode=${widget.mode ?? ''}');
                                } else if (mounted) {
                                  setState(
                                      () => notice = 'Đã ghi sổ chứng từ.');
                                }
                              })
                          : null,
                      child: Text(d['kind'] == 'Receipt'
                          ? (d['reason'] == 'Transfer'
                              ? 'Xác nhận nhập kho & ghi sổ PNK'
                              : 'Hoàn tất phiếu nhập kho')
                          : (d['reason'] == 'Transfer'
                              ? 'Xác nhận xuất luân chuyển & ghi sổ PXK'
                              : 'Xác nhận xuất và ghi sổ PXK'))),
                if (scanHistory.isNotEmpty)
                  const Text('Lịch sử quét pallet',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                for (final s in scanHistory)
                  ListTile(
                      title: Text(asStr(s['palletCode'])),
                      subtitle:
                          Text('${s['scannedByName']} · ${s['scannedAt']}')),
                for (final p in reports) ...[
                  Text('Biên bản ${p['palletCode']}'),
                  for (final c in asMapList(p['cartons']))
                    ListTile(
                        title: Text(asStr(c['cartonCode'])),
                        subtitle: Text(
                            '${receiptDispositionLabel(c['disposition'])} · ${c['reason'] ?? ''} · ${c['quarantineLocation'] ?? ''}'))
                ],
              ]);
            }));
  }
}
