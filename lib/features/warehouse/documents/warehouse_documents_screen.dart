import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/json_utils.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/features/warehouse/widgets/wk_widgets.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/section_title.dart';
import 'package:fscm_mobile/shared/widgets/kv_row.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';
import 'warehouse_documents_api.dart';

final warehouseOperationErrorProvider =
    StateProvider.autoDispose<String?>((ref) => null);

class WarehouseOperationsScreen extends StatelessWidget {
  const WarehouseOperationsScreen({super.key});

  /// One-line description of each operation (from WarehouseDocumentOperations).
  static String _summary(WarehouseOperation operation) => switch (operation) {
        WarehouseOperation.factoryReceipt =>
          'Quét pallet từ nhà máy, kiểm từng thùng rồi xác nhận nhận.',
        WarehouseOperation.transferReceipt =>
          'Mở phiếu nhập từ phiếu xuất luân chuyển và quét từng thùng.',
        WarehouseOperation.orderIssue =>
          'Quét từng thùng theo lệnh xuất bán hàng rồi ghi sổ PXK.',
        WarehouseOperation.transferIssue =>
          'Quét từng thùng theo lệnh điều chuyển để kho đích nhận hàng.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nhập · Xuất kho')),
        body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          const InfoBanner(
              icon: Icons.qr_code_scanner,
              text: 'Chọn nghiệp vụ để mở chứng từ và quét hàng thực tế.'),
          const SectionTitle('Nhập kho'),
          for (final operation in WarehouseOperation.values.take(2))
            WkOperationCard(
                icon: Icons.move_to_inbox,
                title: operation.title,
                summary: _summary(operation),
                onTap: () => context.push('/wk/documents/${operation.name}')),
          const SectionTitle('Xuất kho'),
          for (final operation in WarehouseOperation.values.skip(2))
            WkOperationCard(
                icon: Icons.outbox,
                title: operation.title,
                summary: _summary(operation),
                onTap: () => context.push('/wk/documents/${operation.name}')),
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
                    padding: const EdgeInsets.all(AppSpacing.lg),
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
                      if (history) ...[
                        const SizedBox(height: AppSpacing.s10),
                        const InfoBanner(
                            icon: Icons.history,
                            text:
                                'Chứng từ đã hoàn tất chỉ dùng để xem; không quét lại.'),
                      ],
                      if (operationError != null) ...[
                        const SizedBox(height: AppSpacing.s10),
                        InfoBanner(
                            tone: StatusTone.danger,
                            icon: Icons.error_outline,
                            text: operationError),
                      ],
                      if (arrivals != null && !history) ...[
                        const SectionTitle(
                            'Hàng nhà máy đã xuất về kho của bạn'),
                        AsyncBody(
                            value: arrivals,
                            onRetry: () =>
                                ref.invalidate(factoryArrivalsProvider),
                            builder: (rows) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (rows.isEmpty)
                                        const AppCard(
                                            child: Text(
                                                'Không có pallet chờ nhận.',
                                                style: AppText.muted)),
                                      for (final p in rows)
                                        WkDocumentCard(
                                            code: asStr(p['palletCode']),
                                            subtitle:
                                                '${p['sku']} · ${p['cartonCount']} thùng\nKho nhận: ${warehouseName(p['destinationWarehouseId'])} (cố định)',
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
                                            }),
                                    ])),
                      ],
                      for (final issue in incoming)
                        WkDocumentCard(
                            color: AppColors.infoSoft,
                            code: 'Hàng đang đến: ${issue.document['code']}',
                            subtitle:
                                'Từ ${warehouseName(issue.document['warehouseId'])} · Đã xuất ${issue.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0))} carton\nBấm để mở phiếu nhập & bắt đầu quét carton',
                            onTap: () => context.push(
                                '/wk/document/${issue.id}?mode=transferReceipt')),
                      const SectionTitle('Chứng từ kho'),
                      if (works.isEmpty)
                        const AppCard(
                            child: Text(
                                'Chưa có chứng từ trong phạm vi kho của bạn.',
                                style: AppText.muted)),
                      for (final w in works)
                        WkDocumentCard(
                            code: asStr(w.document['code']),
                            statusLabel: warehouseStatus(w.document['status']),
                            tone: wkStatusTone(w.document['status']),
                            subtitle:
                                '${documentTypeTitle(w.document)} · ${warehouseName(w.document['warehouseId'])}${w.document['destinationWarehouseId'] != null && w.document['destinationWarehouseId'] != w.document['warehouseId'] ? ' → ${warehouseName(w.document['destinationWarehouseId'])}' : ''}',
                            trailingNote:
                                '${w.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0))} carton',
                            onTap: () => context.push(
                                '/wk/document/${w.id}?mode=${operation.name}')),
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
  if (kind == 'Receipt' && reason == 'Transfer') {
    return 'Phiếu nhập luân chuyển';
  }
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
              return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                Text(asStr(d['code']),
                                    style: AppText.cardTitle),
                                StatusChip(
                                    label: warehouseStatus(d['status']),
                                    tone: wkStatusTone(d['status'])),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(documentTypeTitle(d), style: AppText.strong),
                            const SizedBox(height: AppSpacing.s10),
                            if (d['sourceDocumentId'] != null)
                              KvRow('Chứng từ nguồn',
                                  asStr(d['sourceDocumentId'])),
                            KvRow('Kho phụ trách',
                                '${user?.warehouseLabels.where((s) => s.id == d['warehouseId']).map((s) => s.name).firstOrNull ?? d['warehouseId']}'),
                            if (d['destinationWarehouseId'] != null &&
                                d['destinationWarehouseId'] != d['warehouseId'])
                              KvRow('Kho đích',
                                  '${user?.warehouseLabels.where((s) => s.id == d['destinationWarehouseId']).map((s) => s.name).firstOrNull ?? d['destinationWarehouseId']}'),
                            KvRow('Ngày lập', '${d['createdAt']}'),
                            if (d['postedAt'] != null)
                              KvRow('Ghi sổ', '${d['postedAt']}'),
                            if (d['note'] != null &&
                                asStr(d['note']).isNotEmpty)
                              KvRow('Ghi chú', asStr(d['note'])),
                          ]),
                    ),
                    if (error != null)
                      InfoBanner(
                          tone: StatusTone.danger,
                          icon: Icons.error_outline,
                          text: error!),
                    if (notice != null)
                      InfoBanner(
                          tone: StatusTone.success,
                          icon: Icons.check_circle_outline,
                          text: notice!),
                    if (incoming)
                      const InfoBanner(
                          text:
                              'Lô hàng này đã được kho gửi xuất đi. Nhấn "Bắt đầu kiểm nhận & quét QR" để mở phiếu nhập kho đích và quét từng carton.'),
                    if (request && d['reason'] == 'Transfer')
                      const InfoBanner(
                          tone: StatusTone.warning,
                          text:
                              'Đây là Lệnh điều chuyển kho do Admin phát hành. Nhấn "Bắt đầu xuất luân chuyển & quét QR" để bắt đầu soạn và quét carton xuất kho.'),
                    if (request && d['reason'] == 'Order')
                      const InfoBanner(
                          tone: StatusTone.warning,
                          text:
                              'Đây là Lệnh xuất bán hàng do Admin phát hành từ đơn hàng của Đại lý. Nhấn "Bắt đầu xuất kho & quét QR" để mở phiếu xuất và quét từng carton.'),
                    if (d['status'] == 'Posted')
                      const InfoBanner(
                          text:
                              'Phiếu đã ghi sổ. Đây là lịch sử xuất/nhập, không quét lại.'),
                    if (busy) const LinearProgressIndicator(),
                    const SectionTitle('Hàng trong chứng từ'),
                    for (final l in w.lines)
                      AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${l['sku']} · ${l['productName']}',
                                style: AppText.strong),
                            Text(
                                '${l['batchCode'] ?? l['sourceLotCode'] ?? ''}\nHSD: ${l['expirationDate']} · ${l['quantity']} thùng',
                                style: AppText.bodySmall),
                          ])),
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
                          onPressed: busy
                              ? null
                              : () => setState(() => camera = !camera),
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
                                final api =
                                    ref.read(warehouseDocumentsApiProvider);
                                if (w.factory) {
                                  final result = await api.scanPallet(w, code);
                                  if (!mounted) return;
                                  setState(() {
                                    scan = result;
                                    inspection = asMapList(asMap(
                                            result['manifest'])['cartons'])
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
                      const SectionTitle('Kiểm đếm pallet'),
                      AppCard(
                        color: AppColors.infoSoft,
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.inventory_2,
                                      color: AppColors.info),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Pallet: ${scan!['palletCode']}',
                                      style: AppText.strong
                                          .copyWith(color: AppColors.info),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                  'Đã quét lúc: ${scan!['scannedAt']} · Tổng ${inspection.length} thùng',
                                  style: AppText.bodySmall),
                              const SizedBox(height: AppSpacing.sm),
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
                                    icon:
                                        const Icon(Icons.restart_alt, size: 18),
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
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tiến độ kiểm: Đạt: ${inspection.where((c) => c['disposition'] == 'Accepted').length} · Hỏng/Cách ly: ${inspection.where((c) => c['disposition'] == 'Damaged').length} · Thiếu: ${inspection.where((c) => c['disposition'] == 'Missing').length} / ${inspection.length} thùng',
                                style: AppText.strong.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      for (final c in inspection)
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: AppSpacing.s10,
                                children: [
                              Text(asStr(c['cartonCode']),
                                  style: AppText.strong),
                              DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: asStr(c['disposition']),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '', child: Text('Chưa kiểm')),
                                    DropdownMenuItem(
                                        value: 'Accepted', child: Text('Đạt')),
                                    DropdownMenuItem(
                                        value: 'Damaged',
                                        child: Text('Hỏng · cách ly')),
                                    DropdownMenuItem(
                                        value: 'Missing', child: Text('Thiếu'))
                                  ],
                                  onChanged: busy
                                      ? null
                                      : (v) =>
                                          setState(() => c['disposition'] = v)),
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
                                        labelText: 'Vị trí cách ly (bắt buộc)'),
                                    onChanged: (v) => setState(
                                        () => c['quarantineLocation'] = v)),
                            ])),
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
                          child:
                              const Text('Xác nhận kiểm đếm và nhập pallet')),
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
                      AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Tiến độ quét', style: AppText.strong),
                            const SizedBox(height: AppSpacing.xs),
                            Text('Đã quét $scanned / $requiredQuantity thùng',
                                style: AppText.bodySmall),
                            const SizedBox(height: AppSpacing.xs),
                            LinearProgressIndicator(
                                value: requiredQuantity > 0
                                    ? (scanned / requiredQuantity).clamp(0, 1)
                                    : 0),
                          ])),
                    for (final c in w.cartons)
                      AppCard(
                          child: Row(children: [
                        Icon(
                            c['scannedAt'] == null
                                ? Icons.radio_button_unchecked
                                : Icons.check_circle,
                            color: c['scannedAt'] == null
                                ? AppColors.textMuted
                                : AppColors.success),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(asStr(c['cartonId']), style: AppText.strong),
                              Text(
                                  c['scannedAt'] == null
                                      ? 'Chưa quét'
                                      : 'Đã quét: ${c['scannedAt']}',
                                  style: AppText.mutedSmall),
                            ])),
                      ])),
                    if (own && w.pending && !canPost && scan == null)
                      InfoBanner(
                          tone: StatusTone.warning,
                          icon: Icons.warning_amber_rounded,
                          text: w.factory
                              ? 'Cần quét pallet và xác nhận kiểm đếm trước khi ghi sổ phiếu.'
                              : 'Cần quét đủ $requiredQuantity thùng (đã quét $scanned/$requiredQuantity) để ghi sổ.'),
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
                      const SectionTitle('Lịch sử quét pallet'),
                    for (final s in scanHistory)
                      AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(asStr(s['palletCode']), style: AppText.strong),
                            Text('${s['scannedByName']} · ${s['scannedAt']}',
                                style: AppText.mutedSmall),
                          ])),
                    for (final p in reports) ...[
                      SectionTitle('Biên bản ${p['palletCode']}'),
                      for (final c in asMapList(p['cartons']))
                        AppCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(asStr(c['cartonCode']),
                                  style: AppText.strong),
                              Text(
                                  '${receiptDispositionLabel(c['disposition'])} · ${c['reason'] ?? ''} · ${c['quarantineLocation'] ?? ''}',
                                  style: AppText.mutedSmall),
                            ])),
                    ],
                  ]);
            }));
  }
}
