import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/repositories/warehouse_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';

import 'widgets/label_detail_content.dart';

class LabelDetailScreen extends ConsumerWidget {
  const LabelDetailScreen({
    super.key,
    required this.code,
  });

  final String code;

  /// Back to the lookup that opened this label; when opened from a link there
  /// is no previous route, so the lookup is pushed (and keeps a Back button).
  static void _scanAnother(BuildContext context) => context.canPop()
      ? context.pop()
      : unawaited(context.push(AppRoutes.wkLabelLookup));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedCode = code.trim().toUpperCase();
    final provider = labelDetailProvider(normalizedCode);
    final value = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tem $normalizedCode'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: value.isLoading ? null : () => ref.invalidate(provider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Quét mã khác',
            onPressed: () => _scanAnother(context),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: value.when(
        skipLoadingOnRefresh: false,
        data: (detail) => LabelDetailContent(detail: detail),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.error_outline,
          title: _errorTitle(error),
          message: ApiException.describe(error),
          action: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Thử lại'),
              ),
              TextButton(
                onPressed: () => _scanAnother(context),
                child: const Text('Quét hoặc nhập mã khác'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _errorTitle(Object error) {
    if (error is ApiException) {
      switch (error.kind) {
        case ApiErrorKind.notFound:
          return 'Không tìm thấy tem';
        case ApiErrorKind.forbidden:
          return 'Không có quyền truy cập tem';
        case ApiErrorKind.validation:
          return 'Mã tem không hợp lệ';
        case ApiErrorKind.network:
        case ApiErrorKind.timeout:
          return 'Không kết nối được máy chủ';
        default:
          break;
      }
    }

    return 'Không tải được thông tin tem';
  }
}
