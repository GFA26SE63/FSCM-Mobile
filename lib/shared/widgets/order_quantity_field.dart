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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (control == null)
          caption
        else
          LayoutBuilder(builder: (context, constraints) {
            // Preserve the compact one-line footer on normal phone cards;
            // the Expanded caption clips gracefully before it can overlap the
            // fixed-width quantity control. Narrow cards stack the controls.
            final inline = constraints.maxWidth >= 300;
            if (inline) {
              return Row(children: [
                Expanded(child: caption),
                const SizedBox(width: 8),
                control!,
              ]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                caption,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: control!),
              ],
            );
          }),
        if (showRemove)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(0, 40),
              ),
              onPressed: onRemove,
              child: Text(removeLabel),
            ),
          ),
      ],
    );
  }
}
