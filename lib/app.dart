import 'package:flutter/material.dart';
import 'package:fmcg/core/application/app_experience_controller.dart';
import 'package:fmcg/core/application/app_experience_scope.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/features/retailer/application/retailer_controller.dart';
import 'package:fmcg/features/retailer/presentation/retailer_scope.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_login_screen.dart';
import 'package:fmcg/features/retailer/presentation/screens/retailer_shell.dart';
import 'package:fmcg/features/sales/application/sales_controller.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';
import 'package:fmcg/features/sales/presentation/screens/login_screen.dart';
import 'package:fmcg/features/sales/presentation/screens/sales_shell.dart';

class FscmApp extends StatefulWidget {
  const FscmApp({super.key});

  @override
  State<FscmApp> createState() => _FscmAppState();
}

class _FscmAppState extends State<FscmApp> {
  late final SalesController _salesController;
  late final RetailerController _retailerController;
  late final AppExperienceController _experienceController;

  @override
  void initState() {
    super.initState();
    _salesController = SalesController();
    _retailerController = RetailerController();
    _experienceController = AppExperienceController();
  }

  @override
  void dispose() {
    _salesController.dispose();
    _retailerController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppExperienceScope(
      controller: _experienceController,
      child: SalesScope(
        controller: _salesController,
        child: RetailerScope(
          controller: _retailerController,
          child: MaterialApp(
            title: 'FSCM Mobile',
            debugShowCheckedModeBanner: false,
            theme: FscmTheme.light,
            home: AnimatedBuilder(
              animation: Listenable.merge([
                _experienceController,
                _salesController,
                _retailerController,
              ]),
              builder: (context, _) =>
                  switch (_experienceController.experience) {
                    MobileExperience.sales =>
                      _salesController.isAuthenticated
                          ? const SalesShell()
                          : const LoginScreen(),
                    MobileExperience.retailer =>
                      _retailerController.isAuthenticated
                          ? const RetailerShell()
                          : const RetailerLoginScreen(),
                  },
            ),
          ),
        ),
      ),
    );
  }
}
