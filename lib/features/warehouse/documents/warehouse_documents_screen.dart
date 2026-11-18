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
          TextButton(
              onPressed: () => context.push('/wk/order-picking'),
              child: const Text('Danh sách soạn đơn bán hàng')),
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

class WarehouseDocumentsScreen extends ConsumerWidget {
  const WarehouseDocumentsScreen({super.key, required this.operation});
  final WarehouseOperation operation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        scope.contains(w.document['warehouseId']))
                    .toList();
                final incoming = operation == WarehouseOperation.transferReceipt
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
                      if (operationError != null)
                        Text(operationError,
                            style: const TextStyle(color: Colors.red)),
                      if (arrivals != null) ...[
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
                            child: ListTile(
                                title:
                                    Text('Chờ nhận: ${issue.document['code']}'),
                                subtitle: const Text(
                                    'Kho gửi đã xuất. Mở phiếu nhập kho đích để quét từng thùng.'),
                                onTap: () =>
                                    context.push('/wk/document/${issue.id}'))),
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
                                    '${warehouseName(w.document['warehouseId'])} · ${warehouseStatus(w.document['status'])} · ${w.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0))} thùng'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.push('/wk/document/${w.id}'))),
                    ]);
              }),
        ));
  }
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
  const WarehouseDocumentScreen({super.key, required this.id});
  final String id;
  @override ConsumerState<WarehouseDocumentScreen> createState() =>
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
              final incoming = d['kind'] == 'Issue' &&
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
                    '${d['kind'] == 'Receipt' ? 'Phiếu nhập kho' : d['kind'] == 'Issue' ? 'Phiếu xuất kho' : d['kind'] == 'Request' ? 'Yêu cầu kho' : 'Phiếu soạn hàng'} · ${warehouseStatus(d['status'])}'),
                Text(
                    'Kho: ${user?.warehouseLabels.where((s) => s.id == d['warehouseId']).map((s) => s.name).firstOrNull ?? d['warehouseId']}'),
                Text('Ngày lập: ${d['createdAt']}'),
                if (d['postedAt'] != null) Text('Ghi sổ: ${d['postedAt']}'),
                if (d['note'] != null) Text(asStr(d['note'])),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                if (notice != null)
                  Text(notice!, style: const TextStyle(color: Colors.green)),
                if (busy) const LinearProgressIndicator(),
                for (final l in w.lines)
                  Card(
                      child: ListTile(
                          title: Text('${l['sku']} · ${l['productName']}'),
                          subtitle: Text(
                              '${l['batchCode'] ?? l['sourceLotCode'] ?? ''}\nHSD: ${l['expirationDate']} · ${l['quantity']} thùng'))),
                if (request || incoming)
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () => act(() async {
                                final child = await ref
                                    .read(warehouseDocumentsApiProvider)
                                    .child(w.id);
                                if (context.mounted) {
                                  context.pushReplacement(
                                      '/wk/document/${child.id}');
                                }
                              }),
                      child: Text(incoming
                          ? 'Mở phiếu nhập luân chuyển'
                          : 'Mở phiếu soạn để xuất kho')),
                if (editable &&
                    (d['kind'] == 'Receipt' || d['kind'] == 'Picking') &&
                    scan == null)
                  FilledButton.icon(
                      onPressed:
                          busy ? null : () => setState(() => camera = !camera),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(w.factory
                          ? 'Quét pallet thực tế'
                          : 'Quét thùng thực tế')),
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
                  Text(
                      'Pallet: ${scan!['palletCode']} · Đã quét lúc ${scan!['scannedAt']}'),
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
                if (own && (d['kind'] == 'Receipt' || d['kind'] == 'Picking'))
                  FilledButton(
                      onPressed: canPost && scan == null
                          ? () => act(() async {
                                final result = await ref
                                    .read(warehouseDocumentsApiProvider)
                                    .post(w);
                                if (context.mounted && result.id != w.id) {
                                  context.pushReplacement(
                                      '/wk/document/${result.id}');
                                } else if (mounted) {
                                  setState(
                                      () => notice = 'Đã ghi sổ chứng từ.');
                                }
                              })
                          : null,
                      child: Text(d['kind'] == 'Receipt'
                          ? 'Hoàn tất phiếu nhập kho'
                          : 'Xác nhận xuất và lập phiếu xuất kho')),
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
