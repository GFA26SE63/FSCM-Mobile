import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/models/label_info.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

/// "Quét QR": store QR (8-digit code) opens the order screen for that
/// retailer; a shipment label (TEM) shows its order, batch and expiry.
class SalesScanScreen extends ConsumerWidget {
  const SalesScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('Mã điểm bán hoặc tem trên kiện hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Mã điểm bán (QR dán tại cửa hàng) mở ngay trang đặt hàng. Tem hàng trên kiện cho xem đơn, batch, HSD.'),
          const SizedBox(height: 14),
          QrScanView(
            simulated: const <SimulatedScan>[
              SimulatedScan('Quét mã điểm bán 10004127', '10004127'),
              SimulatedScan('Quét điểm bán ngoài khu vực 10004256', '10004256'),
              SimulatedScan('Quét tem TEM-000187', 'TEM-000187'),
            ],
            onCode: (code) => _handle(context, ref, code),
          ),
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String raw) async {
    final code = raw.trim().toUpperCase();
    switch (IdFormat.classify(code)) {
      case ScannedCodeKind.retailer:
        final user = ref.read(currentUserProvider);
        final catalog = await ref.read(catalogProvider.future);
        final retailer = catalog.retailer(code);
        if (!context.mounted) return;
        if (retailer == null) {
          showAppSnack(context,
              'Không tìm thấy điểm bán $code trên máy. Hãy đồng bộ rồi quét lại.',
              error: true);
        } else if (retailer.areaCode != user?.areaCode) {
          showAppSnack(context,
              '${retailer.name} thuộc khu vực ${retailer.areaName}, ngoài khu vực của bạn - không tạo được đơn.',
              error: true);
        } else {
          showAppSnack(context, 'Đã nhận diện ${retailer.name} ($code).');
          unawaited(context.push(AppRoutes.salesNewOrder(code)));
        }
      case ScannedCodeKind.label:
        try {
          final label = await ref.read(warehouseRepositoryProvider).label(code);
          if (!context.mounted) return;
          await _showLabel(context, label);
        } on ApiException catch (e) {
          if (context.mounted) showAppSnack(context, e.message, error: true);
        }
      default:
        showAppSnack(context,
            'Mã "$code" không hợp lệ (cần mã điểm bán 8 số hoặc tem TEM-000000).',
            error: true);
    }
  }

  Future<void> _showLabel(BuildContext context, LabelInfo l) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.code),
        content: Text(
          '${l.sku} · ${l.name}\n${l.qty} thùng\nBatch ${l.batchCode}\nHSD ${AppDates.date(l.expiry)}\n'
          '${l.orderCode.isEmpty ? 'Chưa gán đơn hàng' : 'Thuộc đơn ${l.orderCode}'}\nTrạng thái: ${l.status.label}',
        ),
        actions: <Widget>[
          if (l.orderCode.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push(AppRoutes.salesOrderDetail(l.orderCode));
              },
              child: const Text('Xem đơn'),
            ),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng')),
        ],
      ),
    );
  }
}
