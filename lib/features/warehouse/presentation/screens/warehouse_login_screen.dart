import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/warehouse/presentation/warehouse_scope.dart';
import 'package:fmcg/shared/widgets/experience_switcher.dart';

class WarehouseLoginScreen extends StatefulWidget {
  const WarehouseLoginScreen({super.key});

  @override
  State<WarehouseLoginScreen> createState() => _WarehouseLoginScreenState();
}

class _WarehouseLoginScreenState extends State<WarehouseLoginScreen> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FscmBrandMark(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'FSCM Kho',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Nhập kho, lấy hàng FEFO và quản lý tem truy xuất.',
                    style: TextStyle(color: FscmColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  const TextField(
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      hintText: '0912 440 118',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    key: const Key('warehouseLoginButton'),
                    onPressed: () =>
                        WarehouseScope.of(context, listen: false).login(),
                    child: const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tài khoản được gán theo kho. Mọi thao tác tem và số lượng đều được ghi lịch sử.',
                    style: TextStyle(
                      color: FscmColors.muted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ExperienceSwitcher(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
