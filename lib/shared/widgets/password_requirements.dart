import 'package:flutter/material.dart';

import 'package:fscm_mobile/shared/theme/app_colors.dart';

/// One rule of the account password policy.
class PasswordRequirement {
  const PasswordRequirement(this.label, this.isMet);

  final String label;
  final bool Function(String password) isMet;
}

/// Mirrors the backend `IdentityService.ValidatePassword`: at least 12 characters with an
/// uppercase letter, a lowercase letter, a digit and a special character. Letters and digits
/// are Unicode-aware (`char.IsUpper` / `IsLower` / `IsDigit` / `IsLetterOrDigit` in .NET), so
/// e.g. "Ă" counts as an uppercase letter and not as a special character.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 12;

  static final RegExp _upper = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _lower = RegExp(r'\p{Ll}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);
  static final RegExp _special = RegExp(r'[^\p{L}\p{Nd}]', unicode: true);

  static final List<PasswordRequirement> requirements = <PasswordRequirement>[
    PasswordRequirement(
        'Tối thiểu $minLength ký tự', (p) => p.length >= minLength),
    PasswordRequirement('Ít nhất 1 chữ hoa (A-Z)', _upper.hasMatch),
    PasswordRequirement('Ít nhất 1 chữ thường (a-z)', _lower.hasMatch),
    PasswordRequirement('Ít nhất 1 chữ số (0-9)', _digit.hasMatch),
    PasswordRequirement(
        'Ít nhất 1 ký tự đặc biệt (! @ # \$ % ...)', _special.hasMatch),
  ];

  static bool isValid(String password) =>
      requirements.every((rule) => rule.isMet(password));
}

/// Live checklist under a new-password field: each policy rule turns into a green tick as
/// soon as the typed password satisfies it.
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('password_requirements'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Yêu cầu mật khẩu',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final rule in PasswordPolicy.requirements)
            _RequirementRow(label: rule.label, met: rule.isMet(password)),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.success : AppColors.textMuted;
    return Semantics(
      label: '$label: ${met ? 'đã đạt' : 'chưa đạt'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                met ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey<bool>(met),
                size: 18,
                color: met ? AppColors.success : AppColors.border,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
