import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/status_labels.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:fscm_mobile/core/utils/numbers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fscm_mobile/core/auth/session.dart';
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

/// Filters of the "Chứng từ kho" list. GET /warehouse-documents returns the
/// keeper's complete scope (no paging), so filtering on the device is exact.
class WarehouseDocumentFilter {
  const WarehouseDocumentFilter(
      {this.search = '', this.status, this.warehouseId, this.dates});
  final String search;
  final String? status, warehouseId;

  /// Inclusive range of the document date (createdAt, device local day).
  final DateTimeRange? dates;
  bool get isEmpty =>
      search.trim().isEmpty &&
      status == null &&
      warehouseId == null &&
      dates == null;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

bool _inDates(Object? createdAt, DateTimeRange? dates) {
  if (dates == null) return true;
  final at = DateTime.tryParse(asStr(createdAt));
  if (at == null) return false;
  final day = _day(at.toLocal());
  return !day.isBefore(_day(dates.start)) && !day.isAfter(_day(dates.end));
}

final warehouseDocumentFilterProvider = StateProvider.autoDispose
    .family<WarehouseDocumentFilter, WarehouseOperation>(
        (ref, operation) => const WarehouseDocumentFilter());

List<WarehouseWork> filterWarehouseWorks(
    List<WarehouseWork> works, WarehouseDocumentFilter f) {
  final q = f.search.trim().toLowerCase();
  return works
      .where((w) =>
          (q.isEmpty || asStr(w.document['code']).toLowerCase().contains(q)) &&
          (f.status == null || w.document['status'] == f.status) &&
          (f.warehouseId == null ||
              w.document['warehouseId'] == f.warehouseId ||
              w.document['destinationWarehouseId'] == f.warehouseId) &&
          _inDates(w.document['createdAt'], f.dates))
      .toList();
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
    final names = ref.watch(warehouseNamesProvider).valueOrNull;
    String warehouseName(Object? id) => warehouseLabel(user, names, id);
    final value = ref.watch(warehouseDocumentsProvider);
    final filter = ref.watch(warehouseDocumentFilterProvider(operation));
    final filterNotifier =
        ref.read(warehouseDocumentFilterProvider(operation).notifier);
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
                if (kDebugMode) {
                  // TEMPORARY (debug only): why each document is shown or hidden.
                  debugPrint('[WK-DOCS] ${operation.name} history=$history '
                      'total=${all.length} scope=$scope');
                  for (final w
                      in all.where((w) => operation.includes(w.document))) {
                    final d = w.document;
                    final hasChild =
                        all.any((c) => c.document['sourceDocumentId'] == w.id);
                    final reason = !scope.contains(d['warehouseId'])
                        ? 'HIDDEN: warehouse not in login scope'
                        : (d['kind'] == 'Request' && hasChild)
                            ? 'HIDDEN: request replaced by its child document'
                            : (history ? !w.historic : !w.pending)
                                ? 'HIDDEN: status/kind belongs to the other tab'
                                : 'shown';
                    debugPrint('[WK-DOCS]  ${d['code']} kind=${d['kind']} '
                        'reason=${d['reason']} status=${d['status']} '
                        'warehouse=${d['warehouseId']} '
                        'orders=${w.lines.map((l) => l['orderCode']).toSet()} '
                        'pickingLists=${w.lines.map((l) => l['pickingListId']).toSet()} -> $reason');
                  }
                }
                final works = all
                    .where((w) =>
                        operation.includes(w.document) &&
                        (w.document['kind'] != 'Request' ||
                            !all.any((child) =>
                                child.document['sourceDocumentId'] == w.id)) &&
                        scope.contains(w.document['warehouseId']) &&
                        (history ? w.historic : w.pending))
                    .toList();
                final statuses = {
                  for (final w in works) asStr(w.document['status'])
                }.toList();
                // Options come from the current tab, so a stale choice is dropped.
                final activeFilter = WarehouseDocumentFilter(
                    search: filter.search,
                    status:
                        statuses.contains(filter.status) ? filter.status : null,
                    warehouseId: scope.contains(filter.warehouseId)
                        ? filter.warehouseId
                        : null,
                    dates: filter.dates);
                final shown = filterWarehouseWorks(works, activeFilter);
                final incoming = !history &&
                        operation == WarehouseOperation.transferReceipt
                    ? all
                        .where((w) =>
                            w.document['reason'] == 'Transfer' &&
                            w.document['kind'] == 'Issue' &&
                            w.document['status'] == 'Posted' &&
                            w.transportStatus == 'InTransit' &&
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
                                'Từ ${warehouseName(issue.document['warehouseId'])} · Đã xuất ${formatQuantity(issue.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0)))} carton\nBấm để mở phiếu nhập & bắt đầu quét carton',
                            onTap: () => context.push(
                                '/wk/document/${issue.id}?mode=transferReceipt')),
                      const SectionTitle('Chứng từ kho'),
                      if (works.isNotEmpty)
                        _DocumentFilterBar(
                            filter: activeFilter,
                            statuses: statuses,
                            warehouses: [
                              for (final id in scope) (id, warehouseName(id))
                            ],
                            onChanged: (f) => filterNotifier.state = f),
                      if (works.isEmpty)
                        const AppCard(
                            child: Text(
                                'Chưa có chứng từ trong phạm vi kho của bạn.',
                                style: AppText.muted))
                      else if (shown.isEmpty)
                        const AppCard(
                            child: Text('Không có chứng từ khớp bộ lọc.',
                                style: AppText.muted)),
                      if (works.isNotEmpty && !activeFilter.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                              '${shown.length}/${works.length} chứng từ',
                              style: AppText.mutedSmall),
                        ),
                      for (final w in shown)
                        WkDocumentCard(
                            code: asStr(w.document['code']),
                            statusLabel: warehouseStatus(w.document['status']),
                            tone: wkStatusTone(w.document['status']),
                            subtitle:
                                '${documentTypeTitle(w.document)} · ${warehouseName(w.document['warehouseId'])}${w.document['destinationWarehouseId'] != null && w.document['destinationWarehouseId'] != w.document['warehouseId'] ? ' → ${warehouseName(w.document['destinationWarehouseId'])}' : ''}',
                            trailingNote:
                                '${formatQuantity(w.lines.fold<num>(0, (n, l) => n + (l['quantity'] as num? ?? 0)))} carton',
                            onTap: () => context.push(
                                '/wk/document/${w.id}?mode=${operation.name}')),
                    ]);
              }),
        ));
  }
}

class _DocumentFilterBar extends StatefulWidget {
  const _DocumentFilterBar({
    required this.filter,
    required this.statuses,
    required this.warehouses,
    required this.onChanged,
  });
  final WarehouseDocumentFilter filter;
  final List<String> statuses;
  final List<(String, String)> warehouses;
  final ValueChanged<WarehouseDocumentFilter> onChanged;
  @override
  State<_DocumentFilterBar> createState() => _DocumentFilterBarState();
}

class _DocumentFilterBarState extends State<_DocumentFilterBar> {
  late final search = TextEditingController(text: widget.filter.search);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _emit({String? status, String? warehouseId, DateTimeRange? dates}) =>
      widget.onChanged(WarehouseDocumentFilter(
          search: search.text,
          status: status,
          warehouseId: warehouseId,
          dates: dates));

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final f = widget.filter;
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: f.dates,
        helpText: 'Ngày lập',
        saveText: 'Lọc');
    if (picked != null) {
      _emit(status: f.status, warehouseId: f.warehouseId, dates: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            TextField(
                key: const Key('wk-doc-search'),
                controller: search,
                decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm theo mã chứng từ'),
                onChanged: (_) => _emit(
                    status: f.status,
                    warehouseId: f.warehouseId,
                    dates: f.dates)),
            Row(spacing: AppSpacing.sm, children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                    key: const Key('wk-doc-status'),
                    isExpanded: true,
                    value: f.status,
                    decoration: const InputDecoration(
                        isDense: true, labelText: 'Trạng thái'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Tất cả')),
                      for (final st in widget.statuses)
                        DropdownMenuItem(
                            value: st, child: Text(warehouseStatus(st))),
                    ],
                    onChanged: (v) => _emit(
                        status: v, warehouseId: f.warehouseId, dates: f.dates)),
              ),
              if (widget.warehouses.length > 1)
                Expanded(
                  child: DropdownButtonFormField<String?>(
                      key: const Key('wk-doc-warehouse'),
                      isExpanded: true,
                      value: f.warehouseId,
                      decoration: const InputDecoration(
                          isDense: true, labelText: 'Kho'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Tất cả')),
                        for (final (id, name) in widget.warehouses)
                          DropdownMenuItem(
                              value: id,
                              child:
                                  Text(name, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => _emit(
                          status: f.status, warehouseId: v, dates: f.dates)),
                ),
            ]),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                    key: const Key('wk-doc-dates'),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                        f.dates == null
                            ? 'Ngày lập: tất cả'
                            : 'Ngày lập: ${AppDates.date(f.dates!.start)} – ${AppDates.date(f.dates!.end)}',
                        overflow: TextOverflow.ellipsis),
                    onPressed: _pickDates),
              ),
              if (f.dates != null)
                IconButton(
                    tooltip: 'Bỏ lọc ngày',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        _emit(status: f.status, warehouseId: f.warehouseId)),
            ]),
            if (!f.isEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Xóa bộ lọc'),
                    onPressed: () {
                      search.clear();
                      widget.onChanged(const WarehouseDocumentFilter());
                    }),
              ),
          ]),
    );
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
      _ => unknownStatusLabel,
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
      // Scan history is scoped to the document's own warehouse; a destination
      // keeper viewing the source transfer issue would get a 403 here.
      final work = await ref.read(warehouseDocumentProvider(widget.id).future);
      final ids = ref.read(currentUserProvider)?.warehouseIds;
      if (!ownsDocument(ids, work.document) ||
          isIncomingTransfer(widget.mode, work.document, ids)) {
        return;
      }
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
        // Every open document screen, not only this one: posting also changes
        // the source request still on the back stack (Fulfilled).
        ref.invalidate(warehouseDocumentProvider);
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
    final names = ref.watch(warehouseNamesProvider).valueOrNull;
    // Backend only returns sourceDocumentId (Guid); resolve its code from the scoped list.
    final docCodes = {
      for (final x in ref.watch(warehouseDocumentsProvider).valueOrNull ??
          const <WarehouseWork>[])
        x.id: asStr(x.document['code'])
    };
    return Scaffold(
        appBar: AppBar(title: const Text('Chứng từ kho')),
        body: AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(warehouseDocumentProvider(widget.id)),
            builder: (w) {
              final d = w.document;
              final own = ownsDocument(user?.warehouseIds, d);
              final incoming =
                  isIncomingTransfer(widget.mode, d, user?.warehouseIds);
              // Receiving context: the source issue's scans belong to the
              // sending side, even when this keeper also manages that warehouse.
              final showScanWork = own && !incoming;
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
                            if (docCodes[asStr(d['sourceDocumentId'])]
                                    ?.isNotEmpty ==
                                true)
                              KvRow('Chứng từ nguồn',
                                  docCodes[asStr(d['sourceDocumentId'])]!),
                            KvRow('Kho phụ trách',
                                warehouseLabel(user, names, d['warehouseId'])),
                            if (d['destinationWarehouseId'] != null &&
                                d['destinationWarehouseId'] != d['warehouseId'])
                              KvRow(
                                  'Kho đích',
                                  warehouseLabel(user, names,
                                      d['destinationWarehouseId'])),
                            KvRow('Ngày lập',
                                AppDates.dateTimeText(d['createdAt'])),
                            if (d['postedAt'] != null)
                              KvRow('Ghi sổ',
                                  AppDates.dateTimeText(d['postedAt'])),
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
                    if (d['status'] == 'Posted' && !incoming)
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
                                '${l['batchCode'] ?? l['sourceLotCode'] ?? ''}\nHSD: ${AppDates.dateText(l['expirationDate'])} · ${formatQuantity(l['quantity'])} thùng',
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
                          demoCodes: w.factory
                              ? const <String>[]
                              : d['kind'] == 'Receipt'
                                  ? [
                                      for (final c in w.cartons)
                                        if (c['scannedAt'] == null)
                                          asStr(c['cartonId'])
                                    ]
                                  : w.demoCartonIds,
                          // Each scan bumps the document version; chain them.
                          onDemoScan: (codes) => act(() async {
                                final api =
                                    ref.read(warehouseDocumentsApiProvider);
                                var current = w;
                                for (final code in codes) {
                                  current = await api.scanCarton(current, code);
                                }
                                if (mounted) {
                                  setState(() => notice =
                                      'Đã ghi nhận ${codes.length} thùng. Chờ xác nhận ghi sổ.');
                                }
                              }),
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
                                  'Đã quét lúc: ${AppDates.dateTimeText(scan!['scannedAt'])} · Tổng ${inspection.length} thùng',
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
                    // Source-side issue progress is not this keeper's receipt progress.
                    if (!w.factory && showScanWork)
                      AppCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Tiến độ quét', style: AppText.strong),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                                'Đã quét $scanned / ${formatQuantity(requiredQuantity)} thùng',
                                style: AppText.bodySmall),
                            const SizedBox(height: AppSpacing.xs),
                            LinearProgressIndicator(
                                value: requiredQuantity > 0
                                    ? (scanned / requiredQuantity).clamp(0, 1)
                                    : 0),
                          ])),
                    if (showScanWork)
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
                                Text(asStr(c['cartonId']),
                                    style: AppText.strong),
                                Text(
                                    c['scannedAt'] == null
                                        ? 'Chưa quét'
                                        : 'Đã quét: ${AppDates.dateTimeText(c['scannedAt'])}',
                                    style: AppText.mutedSmall),
                              ])),
                        ])),
                    if (own && w.pending && !canPost && scan == null)
                      InfoBanner(
                          tone: StatusTone.warning,
                          icon: Icons.warning_amber_rounded,
                          text: w.factory
                              ? 'Cần quét pallet và xác nhận kiểm đếm trước khi ghi sổ phiếu.'
                              : 'Cần quét đủ ${formatQuantity(requiredQuantity)} thùng (đã quét $scanned/${formatQuantity(requiredQuantity)}) để ghi sổ.'),
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
                            Text(
                                '${s['scannedByName']} · ${AppDates.dateTimeText(s['scannedAt'])}',
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

/// Warehouse display name: the keeper's own scope labels first, then the
/// warehouse directory (for the other side of a transfer), else the id.
String warehouseLabel(AppUser? user, Map<String, String>? names, Object? id) {
  final own = user?.warehouseLabels.where((w) => w.id == id).firstOrNull?.name;
  if (own != null && own.isNotEmpty) return own;
  final named = names?[asStr(id)];
  return named != null && named.isNotEmpty ? named : asStr(id);
}

/// A posted transfer issue opened from "Nhập luân chuyển" by a keeper of its
/// destination warehouse: the receipt has not been opened yet.
bool isIncomingTransfer(
        String? mode, Map<String, dynamic> doc, List<String>? warehouseIds) =>
    mode == 'transferReceipt' &&
    doc['kind'] == 'Issue' &&
    doc['reason'] == 'Transfer' &&
    doc['status'] == 'Posted' &&
    (warehouseIds?.contains(doc['destinationWarehouseId']) ?? false);

/// Whether the document's operating warehouse is in the keeper's scope.
bool ownsDocument(List<String>? warehouseIds, Map<String, dynamic> doc) =>
    warehouseIds?.contains(doc['warehouseId']) ?? false;
