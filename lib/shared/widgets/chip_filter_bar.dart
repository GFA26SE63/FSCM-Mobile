import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

class ChipOption<T> {
  const ChipOption(this.value, this.label);
  final T value;
  final String label;
}

/// Horizontal single-select filter chips ("Tất cả / Chờ duyệt / ...").
class ChipFilterBar<T> extends StatelessWidget {
  const ChipFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final on = o.value == selected;
          return ChoiceChip(
            label: Text(o.label),
            selected: on,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: on ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide(color: on ? AppColors.primary : AppColors.border),
            onSelected: (_) => onSelected(o.value),
          );
        },
      ),
    );
  }
}
