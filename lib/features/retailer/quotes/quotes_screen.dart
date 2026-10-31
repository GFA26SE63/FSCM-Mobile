import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/utils/dates.dart';
import 'package:fscm_mobile/core/utils/money.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/models/sales_order_quote.dart';
import 'package:fscm_mobile/data/remote/quotes_api.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/quotes_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/app_card.dart';
import 'package:fscm_mobile/shared/widgets/async_body.dart';
import 'package:fscm_mobile/shared/widgets/empty_state.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Báo giá cần xác nhận')),
        body: AsyncBody<List<SalesOrderQuote>>(value: ref.watch(quotesProvider), onRetry: () => ref.invalidate(quotesProvider), builder: (rows) {
          if (rows.isEmpty) return const EmptyState(icon: Icons.request_quote_outlined, title: 'Không có báo giá chờ xác nhận.');
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (_, i) => _QuoteCard(rows[i], ref));
        }),
      );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard(this.quote, this.ref);
  final SalesOrderQuote quote;
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final pending = quote.status == 'PendingRetailerAcceptance';
    final label = pending ? 'Chờ xác nhận' : quote.status == 'Accepted' ? 'Đã xác nhận' : quote.status == 'Rejected' ? 'Đã từ chối' : 'Hết hạn';
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('${quote.orderCode} · Revision ${quote.version}', style: const TextStyle(fontWeight: FontWeight.w800))), StatusChip(label: label, tone: pending ? StatusTone.warning : quote.status == 'Accepted' ? StatusTone.success : StatusTone.neutral)]),
      const SizedBox(height: 6), Text('Giá trị: ${Money.format(quote.totalAmount)}'),
      if (quote.expiresAt != null) Text('Hạn xác nhận: ${AppDates.timeDay(quote.expiresAt)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      if (quote.purchaseOrderCode.isNotEmpty) Text('PO: ${quote.purchaseOrderCode}', style: const TextStyle(color: AppColors.success)),
      if (pending) Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => _reject(context), child: const Text('Từ chối')), const SizedBox(width: 8), FilledButton(onPressed: () => _accept(context), child: const Text('Xác nhận'))]),
    ]));
  }
  Future<void> _accept(BuildContext context) async { await ref.read(quotesApiProvider).accept(quote); ref.read(dataVersionProvider.notifier).state++; }
  Future<void> _reject(BuildContext context) async { final c = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Từ chối báo giá'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Lý do')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().isNotEmpty), child: const Text('Gửi'))])); if (ok == true) { await ref.read(quotesApiProvider).reject(quote, c.text.trim()); ref.read(dataVersionProvider.notifier).state++; } }
}
