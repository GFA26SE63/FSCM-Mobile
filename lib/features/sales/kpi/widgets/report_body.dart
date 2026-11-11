import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/performance.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';

class ReportBody<T> extends StatelessWidget {
  const ReportBody(
      {super.key,
      required this.value,
      required this.reload,
      required this.builder});
  final AsyncValue<T> value;
  final Future<void> Function() reload;
  final Widget Function(T) builder;

  Future<void> _reload() async {
    try {
      await reload();
    } catch (_) {
      // The provider error is rendered by AsyncBody, never as an empty report.
    }
  }

  @override
  Widget build(BuildContext context) => AsyncBody<T>(
      value: value,
      onRetry: () {
        unawaited(_reload());
      },
      builder: (data) => RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: value.isLoading ? null : _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại'))),
                builder(data),
              ],
            ),
          ));
}

class ReportHeader<T> extends StatelessWidget {
  const ReportHeader({super.key, required this.report});
  final PerformanceReport<T> report;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Kỳ: ${report.fromDate} → ${report.toDate}\n'
            'Phạm vi: ${report.scope == 'OwnGroup' || report.scope == 'Group' ? 'Nhóm được cấp quyền' : report.scope}\n'
            'Tải dữ liệu lúc ${AppDates.timeDay(report.loadedAt)} (giờ Việt Nam)'),
      );
}

String reportValue(num value) => value.toString().replaceAll('.', ',');
String reportPercent(num ratio) =>
    '${(ratio * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
