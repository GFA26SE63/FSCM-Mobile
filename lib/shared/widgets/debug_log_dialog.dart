import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_client.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/core/utils/app_logger.dart';

/// Shows an on-device diagnostic and settings bottom sheet.
///
/// Enables testers and developers on physical phones to:
/// 1. Change the API Base URL without recompiling the app.
/// 2. View complete real-time network logs and error stack traces.
/// 3. Copy logs to clipboard for easy sharing.
Future<void> showDebugLogDialog(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) => _DebugLogSheet(ref: ref),
  );
}

class _DebugLogSheet extends StatefulWidget {
  const _DebugLogSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_DebugLogSheet> createState() => _DebugLogSheetState();
}

class _DebugLogSheetState extends State<_DebugLogSheet> {
  late final TextEditingController _urlController;
  List<String> _currentLogs = <String>[];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: Env.effectiveApiBaseUrl);
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _currentLogs = List<String>.from(AppLogger.logs);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl(String newUrl) async {
    final trimmed = newUrl.trim();
    if (trimmed.isEmpty) return;

    Env.setRuntimeApiBaseUrl(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_base_url', trimmed);

    widget.ref.invalidate(apiTransportProvider);
    AppLogger.log('[CONFIG] Đã cập nhật API Base URL thành: $trimmed');
    _refreshLogs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu cấu hình: $trimmed'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _copyAllLogs() async {
    final allLogs = AppLogger.exportAll();
    await Clipboard.setData(ClipboardData(text: allLogs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép toàn bộ log vào bộ nhớ tạm'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearLogs() {
    AppLogger.clear();
    _refreshLogs();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: mediaQuery.size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.bug_report, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Cấu hình & Nhật ký lỗi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Địa chỉ API Máy chủ:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'https://192.168.1.x:7027/api/v1',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => _saveUrl(_urlController.text),
                  child: const Text('Lưu'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _buildPresetChip(
                      'ADB reverse (https)', 'https://localhost:7027/api/v1'),
                  const SizedBox(width: 6),
                  _buildPresetChip(
                      'ADB reverse (http)', 'http://localhost:5080/api/v1'),
                  const SizedBox(width: 6),
                  _buildPresetChip('Emulator (10.0.2.2:5080)',
                      'http://10.0.2.2:5080/api/v1'),
                  const SizedBox(width: 6),
                  _buildPresetChip('Emulator (10.0.2.2:7027)',
                      'https://10.0.2.2:7027/api/v1'),
                ],
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Nhật ký gần đây:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Tải lại',
                      onPressed: _refreshLogs,
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Sao chép',
                      onPressed: _copyAllLogs,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Xóa log',
                      onPressed: _clearLogs,
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _currentLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có log nào.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _currentLogs.length,
                        itemBuilder: (context, index) {
                          final log = _currentLogs[index];
                          final isError = log.contains('[ERROR]');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: isError
                                    ? Colors.red.shade800
                                    : Colors.black87,
                                fontWeight: isError
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        _urlController.text = url;
        _saveUrl(url);
      },
    );
  }
}
