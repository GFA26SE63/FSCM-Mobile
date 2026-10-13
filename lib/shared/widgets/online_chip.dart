import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/network/network_monitor.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/shared/widgets/status_chip.dart';

/// "Đang online / Đang offline" indicator.
class OnlineChip extends ConsumerWidget {
  const OnlineChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(networkMonitorProvider).online;
    return StatusChip(
      label: online ? 'Đang online' : 'Đang offline',
      tone: online ? StatusTone.success : StatusTone.warning,
    );
  }
}
