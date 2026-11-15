import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/enums.dart';
import 'package:fscm_mobile/data/models/order.dart';
import 'package:fscm_mobile/data/remote/orders_api.dart';
import 'package:fscm_mobile/data/repositories/data_version.dart';
import 'package:fscm_mobile/data/repositories/order_repository.dart';
import 'dialogs.dart';

class AllocationRetryButton extends ConsumerStatefulWidget {
  const AllocationRetryButton({super.key, required this.order});
  final Order order;
  @override
  ConsumerState<AllocationRetryButton> createState() =>
      _AllocationRetryButtonState();
}

class _AllocationRetryButtonState extends ConsumerState<AllocationRetryButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    if (![OrderStatus.allocationFailed, OrderStatus.allocationConflict]
        .contains(widget.order.status)) {
      return const SizedBox.shrink();
    }
    return FilledButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await ref
                      .read(ordersApiProvider)
                      .retryAllocation(widget.order.id, widget.order.version);
                  ref
                      .read(dataVersionProvider.notifier)
                      .update((value) => value + 1);
                  ref.invalidate(orderDetailProvider(widget.order.code));
                } on ApiException catch (e) {
                  if (context.mounted) {
                    showAppSnack(context, e.message, error: true);
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Text(_busy ? 'Đang phân bổ...' : 'Thử phân bổ lại'));
  }
}
