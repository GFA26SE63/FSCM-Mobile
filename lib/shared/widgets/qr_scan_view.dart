import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// A code the mock/demo mode can "scan" with one tap (no camera needed).
class SimulatedScan {
  const SimulatedScan(this.label, this.code);
  final String label;
  final String code;
}

/// Camera QR scanner with a manual-entry field. In mock mode it also lists
/// [simulated] one-tap codes like the "Giả lập quét (prototype)" buttons.
class QrScanView extends StatefulWidget {
  const QrScanView({
    super.key,
    required this.onCode,
    this.hint = 'Đưa mã QR vào khung',
    this.simulated = const <SimulatedScan>[],
    this.manualLabel = 'Hoặc nhập mã thủ công',
    this.height = 260,
  });

  /// Called with the raw text of each (de-duplicated) scan.
  final ValueChanged<String> onCode;
  final String hint;
  final List<SimulatedScan> simulated;
  final String manualLabel;
  final double height;

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
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
                      const _CameraUnavailable(),
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
        const SizedBox(height: 12),
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
              onPressed: () => _submitManual(_manual.text),
              child: const Text('OK'),
            ),
          ],
        ),
        if (Env.useMock && widget.simulated.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          const Text(
            'Giả lập quét (demo)',
            style: TextStyle(
                color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final s in widget.simulated)
                OutlinedButton(
                  onPressed: () {
                    _lastCode = null;
                    _emit(s.code);
                  },
                  child: Text(s.label),
                ),
            ],
          ),
        ],
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
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1B1F1D),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Không mở được camera. Cấp quyền camera hoặc nhập mã thủ công bên dưới.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
