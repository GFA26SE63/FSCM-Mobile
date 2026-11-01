import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
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
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FscmLogo(
              size: 84,
              iconSize: 46,
              borderRadius: 24,
              backgroundColor: Colors.white,
              iconColor: AppColors.primary,
              strokeWidth: 2.0,
            ),
            SizedBox(height: 20),
            Text(
              'FSCM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Hệ thống quản lý chuỗi cung ứng',
              style: TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Đang tải...',
              style: TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
