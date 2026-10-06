import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';

class InventoryLabelCard extends StatelessWidget {
  const InventoryLabelCard({
    super.key,
    required this.labelId,
    required this.sku,
    required this.quantity,
    required this.batchCode,
    required this.expiryDate,
    required this.location,
    this.destination,
    this.status,
    this.statusColor = FscmColors.primary,
    this.onTap,
  });

  final String labelId;
  final String sku;
  final int quantity;
  final String batchCode;
  final String expiryDate;
  final String location;
  final String? destination;
  final String? status;
  final Color statusColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FscmCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: FscmColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.qr_code_2, size: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        labelId,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (status != null)
                      StatusPill(label: status!, color: statusColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$sku · $quantity thùng',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Batch $batchCode',
                  style: const TextStyle(color: FscmColors.muted, fontSize: 12),
                ),
                Text(
                  'HSD $expiryDate · $location',
                  style: const TextStyle(color: FscmColors.muted, fontSize: 12),
                ),
                if (destination != null)
                  Text(
                    destination!,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minimum = 1,
    this.maximum,
  });

  final int value;
  final int minimum;
  final int? maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: value > minimum ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.outlined(
          onPressed: maximum == null || value < maximum!
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    super.key,
    required this.label,
    required this.completed,
    required this.total,
    this.note,
  });

  final String label;
  final int completed;
  final int total;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    return FscmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$completed/$total',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: const TextStyle(color: FscmColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
