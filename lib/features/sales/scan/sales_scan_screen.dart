import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/data/repositories/catalog_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/dialogs.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

class SalesScanScreen extends ConsumerStatefulWidget {
  const SalesScanScreen({super.key});

  @override
  ConsumerState<SalesScanScreen> createState() => _SalesScanScreenState();
}

class _SalesScanScreenState extends ConsumerState<SalesScanScreen> {
  bool _busy = false;

  Future<void> _handle(String raw) async {
    if (_busy) return;

    final code = raw.trim().toUpperCase();
    final kind = IdFormat.classify(code);

    if (kind == ScannedCodeKind.label) {
      showAppSnack(
        context,
        'Tra cứu tem kho hiện dành cho Warehouse Keeper.',
        error: true,
      );
      return;
    }

    if (kind != ScannedCodeKind.retailer) {
      showAppSnack(
        context,
        'Hãy quét mã điểm bán gồm 8 chữ số.',
        error: true,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _busy = true);

    try {
      final catalog = await ref.read(catalogProvider.future);

      if (!mounted) return;
      if (ref.read(currentUserProvider)?.id != user.id) return;

      final retailer = catalog.retailer(code);

      if (retailer == null) {
        showAppSnack(
          context,
          'Điểm bán $code không có trong snapshot hiện tại. '
          'Hãy cập nhật danh sách điểm bán phụ trách rồi thử lại.',
          error: true,
        );
        return;
      }

      await context.push<void>(
        AppRoutes.salesRetailerDetail(retailer.code),
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          ApiException.describe(error),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã điểm bán')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Quét mã điểm bán để xem thông tin và kiểm tra '
            'điều kiện đặt hàng.',
          ),
          const SizedBox(height: 14),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else
            QrScanView(onCode: _handle),
        ],
      ),
    );
  }
}
