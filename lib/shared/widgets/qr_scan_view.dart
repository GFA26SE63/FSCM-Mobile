import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/data/remote/order_configuration_api.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera QR scanner with a manual-entry field.
class QrScanView extends ConsumerStatefulWidget {
  const QrScanView({
    super.key,
    required this.onCode,
    this.hint = 'Đưa mã QR vào khung',
    this.manualLabel = 'Hoặc nhập mã thủ công',
    this.height = 260,
    this.allowManual = true,
    this.demoCodes = const <String>[],
    this.onDemoScan,
  });

  /// Called with the raw text of each (de-duplicated) scan.
  final ValueChanged<String> onCode;
  final String hint;
  final String manualLabel;
  final double height;
  final bool allowManual;

  /// Real codes still expected by the screen. The "Quét nhanh" button shows
  /// only while the admin demo switch is on and this list is not empty.
  final List<String> demoCodes;

  /// Async handler for all [demoCodes] at once; defaults to [onCode] per code.
  final Future<void> Function(List<String> codes)? onDemoScan;

  @override
  ConsumerState<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends ConsumerState<QrScanView> {
  bool _demoBusy = false;

  Future<void> _demoScan() async {
    final codes = List<String>.of(widget.demoCodes);
    setState(() => _demoBusy = true);
    try {
      if (widget.onDemoScan != null) {
        await widget.onDemoScan!(codes);
      } else {
        // Same path as a camera scan, so every screen check still runs.
        codes.forEach(widget.onCode);
      }
    } finally {
      if (mounted) setState(() => _demoBusy = false);
    }
  }

  final TextEditingController _manual = TextEditingController();
  String? _lastCode;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _manual.dispose();
    super.dispose();
  }

  void _emit(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    // The camera reports the same code every frame: ignore repeats briefly.
    if (code == _lastCode) return;
    _lastCode = code;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => _lastCode = null);
    widget.onCode(code);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MobileScanner(
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final v = b.rawValue;
                      if (v != null && v.isNotEmpty) {
                        _emit(v);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error, child) =>
                      _CameraUnavailable(allowManual: widget.allowManual),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Text(
                    widget.hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: <Shadow>[Shadow(blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.demoCodes.isNotEmpty &&
            (ref.watch(demoFastScanProvider).valueOrNull ?? false)) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _demoBusy ? null : _demoScan,
            icon: const Icon(Icons.bolt),
            label: Text(_demoBusy
                ? 'Đang quét nhanh...'
                : 'Quét nhanh ${widget.demoCodes.length} mã (demo)'),
          ),
        ],
        if (widget.allowManual) const SizedBox(height: 12),
        if (widget.allowManual)
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _manual,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: widget.manualLabel),
                  onSubmitted: _submitManual,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                onPressed: () => _submitManual(_manual.text),
                child: const Text('OK'),
              ),
            ],
          ),
      ],
    );
  }

  void _submitManual(String text) {
    _lastCode = null;
    _emit(text);
    _manual.clear();
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.allowManual});
  final bool allowManual;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B1F1D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            allowManual
                ? 'Không mở được camera. Cấp quyền camera hoặc nhập mã thủ công bên dưới.'
                : 'Không mở được camera. Cấp quyền camera để quét hàng thực tế.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
