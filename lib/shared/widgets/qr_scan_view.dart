import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera QR scanner with a manual-entry field.
class QrScanView extends StatefulWidget {
  const QrScanView({
    super.key,
    required this.onCode,
    this.hint = 'Đưa mã QR vào khung',
    this.manualLabel = 'Hoặc nhập mã thủ công',
    this.height = 260,
    this.allowManual = true,
    this.demoCodes = const <String>[],
    this.onDemoScan,
    this.demoCount,
  });

  /// Called with the raw text of each (de-duplicated) scan.
  final ValueChanged<String> onCode;
  final String hint;
  final String manualLabel;
  final double height;
  final bool allowManual;

  /// Real codes still expected by the screen. The server sends them only while
  /// the admin demo switch is on; the "Quét nhanh" button shows when non-empty.
  final List<String> demoCodes;

  /// Async handler for the first [count] of [demoCodes] (fewer when the
  /// screen still has to fetch codes); defaults to [onCode] per code.
  final Future<void> Function(List<String> codes, int count)? onDemoScan;

  /// Overrides the shown count when [onDemoScan] can still fetch codes itself.
  final int? demoCount;

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  bool _demoBusy = false;
  final TextEditingController _demoQty = TextEditingController();
  String _demoError = '';

  int get _demoMax => widget.demoCount ?? widget.demoCodes.length;

  Future<void> _demoScan() async {
    final text = _demoQty.text.trim();
    final count = text.isEmpty ? _demoMax : int.tryParse(text);
    if (count == null || count < 1 || count > _demoMax) {
      setState(() => _demoError = 'Nhập số thùng từ 1 đến $_demoMax.');
      return;
    }
    final codes = widget.demoCodes.take(count).toList(growable: false);
    setState(() {
      _demoBusy = true;
      _demoError = '';
    });
    try {
      if (widget.onDemoScan != null) {
        await widget.onDemoScan!(codes, count);
      } else {
        // Same path as a camera scan, so every screen check still runs.
        codes.forEach(widget.onCode);
      }
      _demoQty.clear();
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
    _demoQty.dispose();
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
        if (_demoMax > 0) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _demoQty,
                  enabled: !_demoBusy,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số thùng',
                    hintText: 'Tối đa $_demoMax',
                  ),
                  onSubmitted: (_) => _demoScan(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _demoBusy ? null : _demoScan,
                  icon: const Icon(Icons.bolt),
                  label: Text(_demoBusy
                      ? 'Đang quét nhanh...'
                      : 'Quét nhanh (demo) · còn $_demoMax'),
                ),
              ),
            ],
          ),
          if (_demoError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _demoError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
