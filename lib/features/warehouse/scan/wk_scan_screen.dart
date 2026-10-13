import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

/// Central "Quét QR" of the Warehouse Keeper: classifies the code and opens
/// the label, picking list or transfer slip. With [labelsOnly] it is the
/// "Tra cứu tem" screen reached from the home page.
class WkScanScreen extends ConsumerStatefulWidget {
  const WkScanScreen({super.key, this.labelsOnly = false});

  final bool labelsOnly;

  @override
  ConsumerState<WkScanScreen> createState() => _WkScanScreenState();
}

class _WkScanScreenState extends ConsumerState<WkScanScreen> {
  String _error = '';

  Future<void> _onCode(String raw) async {
    final code = raw.trim().toUpperCase();
    final kind = IdFormat.classify(code);
    String? route;
    switch (kind) {
      case ScannedCodeKind.label:
        // Make sure the label exists before navigating.
        try {
          await ref.read(warehouseRepositoryProvider).label(code);
        } on ApiException catch (e) {
          if (mounted) setState(() => _error = e.message);
          return;
        }
        route = AppRoutes.wkLabel(code);
        break;
      case ScannedCodeKind.pickingList:
        route = widget.labelsOnly ? null : AppRoutes.wkPickingDetail(code);
        break;
      case ScannedCodeKind.document:
        route = (widget.labelsOnly || !code.startsWith('DC-'))
            ? null
            : AppRoutes.wkTransferDetail(code);
        break;
      default:
        route = null;
    }
    if (!mounted) return;
    if (route == null) {
      setState(() => _error = widget.labelsOnly
          ? 'Mã "$code" không phải tem (TEM-000000).'
          : 'Không nhận diện được mã "$code". Quét tem, phiếu picking (DH-000000A) hoặc phiếu chuyển kho (DC-yyMMdd-nn).');
      return;
    }
    setState(() => _error = '');
    unawaited(context.push(route));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.labelsOnly ? 'Tra cứu tem' : 'Quét QR';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const <Widget>[NotificationBellButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          InfoBanner(
            icon: Icons.qr_code_scanner,
            text: widget.labelsOnly
                ? 'Quét tem để xem batch, số lượng, vị trí, tem gốc/con và lịch sử.'
                : 'Quét tem để tra cứu, phiếu picking để lấy hàng hoặc phiếu chuyển kho để nhận hàng.',
          ),
          QrScanView(
            onCode: _onCode,
            simulated: widget.labelsOnly
                ? const <SimulatedScan>[
                    SimulatedScan('Tem TEM-000210', 'TEM-000210'),
                    SimulatedScan('Tem TEM-000142', 'TEM-000142'),
                  ]
                : const <SimulatedScan>[
                    SimulatedScan('Tem TEM-000210', 'TEM-000210'),
                    SimulatedScan('Phiếu DH-001024A', 'DH-001024A'),
                    SimulatedScan('Phiếu DC-260926-01', 'DC-260926-01'),
                  ],
          ),
          if (_error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            InfoBanner(
                tone: StatusTone.danger,
                icon: Icons.error_outline,
                text: _error),
          ],
        ],
      ),
    );
  }
}
