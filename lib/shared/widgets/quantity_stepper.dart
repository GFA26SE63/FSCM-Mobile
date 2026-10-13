import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// − [value] + control; [step] cartons per tap, clamped to 0..[max].
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
  });

  final int value;
  final int step;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _btn(Icons.remove,
            value - step >= min ? () => onChanged(value - step) : null),
        SizedBox(
          width: 52,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        _btn(Icons.add,
            value + step <= max ? () => onChanged(value + step) : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 40,
        height: 40,
        child: IconButton.outlined(
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.border)),
          onPressed: onTap,
          icon: Icon(icon, size: 20),
        ),
      );
}
