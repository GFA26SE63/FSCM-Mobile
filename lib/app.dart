import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _salesController = SalesController();
  }

  @override
  void dispose() {
    _salesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SalesScope(
      controller: _salesController,
      child: MaterialApp(
        title: 'FSCM Sales',
        debugShowCheckedModeBanner: false,
        theme: FscmTheme.light,
        home: AnimatedBuilder(
          animation: _salesController,
          builder: (context, _) => _salesController.isAuthenticated
              ? const SalesShell()
              : const LoginScreen(),
        ),
      ),
    );
  }
}
