import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// Order-card footer: the quantity control stays on the right; removal has its
/// own line so it never takes space from the label or the plus button.
class OrderQuantityField extends StatelessWidget {
  const OrderQuantityField({
    super.key,
    required this.label,
    this.control,
    this.labelColor = AppColors.textMuted,
    this.showRemove = false,
    this.onRemove,
    this.removeLabel = 'Bỏ khỏi giỏ',
  });

  final String label;
  final Widget? control;
  final Color labelColor;
  final bool showRemove;
  final VoidCallback? onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context)
        .style
        .copyWith(color: labelColor, fontSize: 13);
    final caption = Text(label, style: style);
    // Trash icon sits right of the stepper, like a shopping-cart row.
    final remove = IconButton(
      tooltip: removeLabel,
      color: AppColors.textMuted,
      onPressed: onRemove,
      icon: const Icon(Icons.delete_outline, size: 26),
    );
    if (control == null) {
      return showRemove
          ? Row(children: [Expanded(child: caption), remove])
          : caption;
    }
    // Caption on its own line; stepper left, trash right on the row below.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) caption,
        // Separates product info and caption above from the quantity controls.
        const Divider(height: 17, thickness: 1, color: AppColors.divider),
        Row(children: [
          control!,
          const Spacer(),
          if (showRemove) remove,
        ]),
      ],
    );
  }
}
