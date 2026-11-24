import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/fscm_logo.dart';

/// Restores the stored session; the router redirects away afterwards.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(authControllerProvider.notifier).restore(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const onBrand = AppColors.onPrimary;
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        // Scrolls (never clips) when the system font scale is large.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const FscmLogo(
                  size: 84,
                  borderRadius: 24,
                  backgroundColor: AppColors.surface,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'FSCM',
                  style: AppText.display.copyWith(
                    color: onBrand,
                    fontSize: 32,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  'Hệ thống quản lý chuỗi cung ứng',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(
                    color: onBrand.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: onBrand,
                    backgroundColor: onBrand.withValues(alpha: 0.2),
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.card),
                Text(
                  'Đang tải...',
                  style: AppText.bodySmall
                      .copyWith(color: onBrand.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
