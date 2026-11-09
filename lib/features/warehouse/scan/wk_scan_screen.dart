import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/id_format.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/features/common/notifications/notification_bell_button.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/qr_scan_view.dart';

class WkScanScreen extends ConsumerStatefulWidget {
  const WkScanScreen({
    super.key,
    this.labelsOnly = false,
  });

  final bool labelsOnly;

  @override
  ConsumerState<WkScanScreen> createState() => _WkScanScreenState();
}

class _WkScanScreenState extends ConsumerState<WkScanScreen> {
  String _error = '';
  bool _opening = false;

  Future<void> _onCode(String raw) async {
    if (_opening) return;

    final code = raw.trim().toUpperCase();
    final kind = IdFormat.classify(code);

    String? route;

    if (kind == ScannedCodeKind.label) {
      route = AppRoutes.wkLabel(code);
    } else if (!widget.labelsOnly && kind == ScannedCodeKind.pickingList) {
      route = AppRoutes.wkPickingDetail(code);
    }

    if (route == null) {
      setState(() {
        _error = widget.labelsOnly
            ? 'Mã không phải tem QR hợp lệ. Ví dụ: TEM-001010.'
            : 'Hãy quét mã tem hoặc mã phiếu picking hợp lệ.';
      });
      return;
    }

    setState(() {
      _opening = true;
      _error = '';
    });

    try {
      await context.push<void>(route);
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.labelsOnly ? 'Tra cứu tem' : 'Quét QR'),
        actions: const [NotificationBellButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoBanner(
            icon: Icons.qr_code_scanner,
            text: widget.labelsOnly
                ? 'Quét hoặc nhập mã tem để xem sản phẩm, batch, '
                    'số lượng, kho và lịch sử. Tra cứu cần kết nối mạng.'
                : 'Quét tem để tra cứu hoặc phiếu picking để lấy hàng.',
          ),
          const SizedBox(height: 12),
          if (_opening)
            const Center(child: CircularProgressIndicator())
          else
            QrScanView(onCode: _onCode),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBanner(
              tone: StatusTone.danger,
              icon: Icons.error_outline,
              text: _error,
            ),
          ],
        ],
      ),
    );
  }
}
