import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/clock.dart';
import 'package:fscm_mobile/data/models/offline_order.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/repositories/order_configuration_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/features/sales/orders/order_confirm_sheet.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/quantity_stepper.dart';
import 'package:fscm_mobile/shared/widgets/order_quantity_field.dart';

class DraftEditScreen extends ConsumerStatefulWidget {
  const DraftEditScreen({
    super.key,
    required this.entry,
  });

  final OfflineOrder entry;

  @override
  ConsumerState<DraftEditScreen> createState() => _DraftEditScreenState();
}

class _DraftEditScreenState extends ConsumerState<DraftEditScreen> {
  late List<CartLine> _lines;
  String? _selectedSku;
  bool _saving = false;
  final Set<String> _invalidQuantities = <String>{};

  @override
  void initState() {
    super.initState();
    _lines = List<CartLine>.of(widget.entry.payload.lines);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sửa ${widget.entry.localCode}'),
        ),
        body: AsyncBody<CatalogData>(
          value: catalog,
          onRetry: () => ref.invalidate(catalogProvider),
          builder: (data) => AsyncBody<int>(
            value: ref.watch(orderStepProvider),
            onRetry: () => ref.invalidate(orderStepProvider),
            builder: (step) => _body(data, step),
          ),
        ),
      ),
    );
  }

  Widget _body(CatalogData data, int step) {
    final remaining = data.products
        .where(
          (product) =>
              product.id.isNotEmpty &&
              !_lines.any((line) => line.sku == product.sku),
        )
        .toList();

    final selected = remaining.any(
      (product) => product.sku == _selectedSku,
    )
        ? _selectedSku
        : null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${widget.entry.payload.retailerName} · '
                '${widget.entry.payload.retailerCode}',
              ),
              const SizedBox(height: 12),
              const InfoBanner(
                text: 'Sửa draft chưa gửi. Khi lưu, bạn sẽ xem lại '
                    'giá và khuyến mãi tạm tính từ snapshot trên máy. '
                    'Thao tác này chưa gửi đơn và chưa giữ hàng.',
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _lines.length; index++)
                _line(data, index, step),
              if (_lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Draft chưa có sản phẩm.'),
                ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                value: selected,
                hint: const Text('Chọn sản phẩm để thêm'),
                items: [
                  for (final product in remaining)
                    DropdownMenuItem(
                      value: product.sku,
                      child: Text(
                        '${product.sku} · ${product.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _selectedSku = value);
                      },
              ),
              OutlinedButton.icon(
                onPressed: _saving || selected == null
                    ? null
                    : () {
                        final product = remaining.firstWhere(
                          (item) => item.sku == selected,
                        );

                        setState(() {
                          _lines.add(
                            CartLine(
                              productId: product.id,
                              sku: product.sku,
                              qty: step,
                            ),
                          );
                          _selectedSku = null;
                        });
                      },
                icon: const Icon(Icons.add),
                label: const Text('Thêm sản phẩm'),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || _lines.isEmpty || _invalidQuantities.isNotEmpty ? null : () => _save(data),
                child: Text(
                  _saving ? 'Đang lưu...' : 'Xem lại tạm tính và lưu draft',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(CatalogData data, int index, int step) {
    final line = _lines[index];
    final name = data.product(line.sku)?.name ?? line.sku;

    return Padding(
      key: ValueKey(line.sku),
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${line.sku} · $name',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            OrderQuantityField(
              label: 'Số lượng (thùng)',
              showRemove: true,
              removeLabel: 'Bỏ khỏi draft',
              onRemove: _saving ? null : () => _removeLine(line),
              control: QuantityStepper(
                  editable: true,
                  enabled: !_saving,
                  value: line.qty,
                  min: step,
                  max: 2147483647,
                  step: step,
                  onValidationChanged: (valid) => setState(() {
                    if (valid) {
                      _invalidQuantities.remove(line.sku);
                    } else {
                      _invalidQuantities.add(line.sku);
                    }
                  }),
                  onChanged: (quantity) {
                    final current = _lines.indexWhere((item) => item.sku == line.sku);
                    if (!_saving && current >= 0) {
                      setState(() => _lines[current] = line.withQty(quantity));
                    }
                  },
                ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _removeLine(CartLine line) {
    final ownerId = ref.read(currentUserProvider)?.id;
    final index = _lines.indexWhere((item) => item.sku == line.sku);
    if (_saving || ownerId == null || index < 0) {
      return;
    }
    setState(() {
      _lines.removeAt(index);
      _invalidQuantities.remove(line.sku);
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      persist: false,
      content: Text('Đã bỏ ${line.sku} khỏi draft.'),
      action: SnackBarAction(label: 'Hoàn tác', onPressed: () {
        if (!mounted || _saving || ref.read(currentUserProvider)?.id != ownerId ||
            _lines.any((item) => item.sku == line.sku)) {
          return;
        }
        setState(() {
          _lines.insert(index > _lines.length ? _lines.length : index, line);
          _invalidQuantities.remove(line.sku);
        });
      }),
    ));
  }

  Future<void> _save(CatalogData data) async {
    setState(() => _saving = true);

    try {
      final step = await ref.read(orderStepProvider.future);
      if (!mounted) {
        return;
      }
      if (_invalidQuantities.isNotEmpty || _lines.any((line) => line.qty <= 0 || line.qty % step != 0)) {
        throw ApiException(
            kind: ApiErrorKind.validation,
            message: 'Số lượng phải là số thùng nguyên dương theo bước $step.');
      }
      final snapshot = data.snapshot;
      final retailer = data.retailer(
        widget.entry.payload.retailerCode,
      );

      if (snapshot == null || retailer == null) {
        throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Snapshot chưa có đủ dữ liệu điểm bán để sửa draft.',
        );
      }

      if (retailer.id != widget.entry.payload.retailerId) {
        throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Thông tin điểm bán không khớp draft.',
        );
      }

      final lines = List<CartLine>.unmodifiable(_lines);

      for (final line in lines) {
        final product = data.product(line.sku);

        if (product == null || product.id != line.productId) {
          throw ApiException(
            kind: ApiErrorKind.validation,
            message: 'Sản phẩm ${line.sku} không còn trong snapshot.',
          );
        }
      }

      final estimatedAt = AppClock.now();
      final estimate = data.quote(
        lines,
        retailer.code,
        now: estimatedAt,
      );

      if (!estimate.isComplete) {
        throw ApiException(
          kind: ApiErrorKind.validation,
          message: 'Thiếu giá: ${estimate.missingPriceSkus.join(', ')}.',
        );
      }

      final repository = ref.read(orderRepositoryProvider);

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => OrderConfirmSheet(
          retailer: retailer,
          quote: estimate,
          online: false,
          estimated: true,
          snapshotAt: data.lastSyncAt,
          estimatedAt: estimatedAt,
        ),
      );

      if (!mounted || confirmed != true) {
        return;
      }

      await repository.editOffline(
        orderStep: step,
        original: widget.entry,
        lines: lines,
        estimate: estimate,
        estimatedAt: estimatedAt,
        snapshot: snapshot,
      );

      if (!mounted) {
        return;
      }

      ref.read(dataVersionProvider.notifier).state++;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          ApiException.describe(error),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
