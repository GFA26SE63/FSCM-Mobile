import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/data/models/complaint.dart';
import 'package:fscm_mobile/data/repositories/loyalty_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// Own complaints (KN-yyMMdd-nn) with their processing status.
class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(complaintsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khiếu nại')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.rtComplaintNew),
        icon: const Icon(Icons.add),
        label: const Text('Tạo khiếu nại'),
      ),
      body: AsyncBody<List<Complaint>>(
        value: value,
        onRetry: () => ref.invalidate(complaintsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.report_gmailerrorred_outlined,
                title: 'Chưa có khiếu nại nào.');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                            child: Text(c.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        StatusChip(label: c.status.label, tone: c.status.tone),
                      ],
                    ),
                    Text('${c.orderCode} · ${c.sku} ${c.name}'),
                    Text(
                      'Đặt ${c.expectedQty} · thực nhận ${c.actualQty} (thiếu ${c.shortfall})',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                    ),
                    if (c.note.isNotEmpty)
                      Text('"${c.note}"', style: const TextStyle(fontSize: 13)),
                    if (c.response.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text('Phản hồi: ${c.response}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                    Text(AppDates.timeDay(c.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
