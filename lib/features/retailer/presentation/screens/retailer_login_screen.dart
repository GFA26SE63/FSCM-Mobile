import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/core/widgets/fscm_components.dart';
import 'package:fmcg/features/retailer/presentation/retailer_scope.dart';
import 'package:fmcg/shared/widgets/experience_switcher.dart';

class RetailerLoginScreen extends StatefulWidget {
  const RetailerLoginScreen({super.key});

  @override
  State<RetailerLoginScreen> createState() => _RetailerLoginScreenState();
}

class _RetailerLoginScreenState extends State<RetailerLoginScreen> {
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
                    'FSCM Retailer',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Xác nhận nhận hàng, theo dõi chi tiêu và quyền lợi.',
                    style: TextStyle(color: FscmColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  const TextField(
                    key: Key('retailerPhoneField'),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      hintText: '0908 412 700',
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
                    key: const Key('retailerLoginButton'),
                    onPressed: () =>
                        RetailerScope.of(context, listen: false).login(),
                    child: const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tài khoản điểm bán do nhà phân phối cấp. Retailer không tạo đơn hàng trong ứng dụng này.',
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
