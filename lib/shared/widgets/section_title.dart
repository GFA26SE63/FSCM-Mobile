import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';

/// Section heading with an optional trailing widget.
///
/// The prototype's `.sec` is upper-case; the text is deliberately kept as
/// supplied by the caller (no case transform) so Vietnamese labels and widget
/// tests are unchanged.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxs, AppSpacing.card, AppSpacing.xxs, AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: AppText.sectionTitle.copyWith(color: AppColors.text),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
