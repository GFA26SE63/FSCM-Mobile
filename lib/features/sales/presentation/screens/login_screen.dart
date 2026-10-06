import 'package:flutter/material.dart';
import 'package:fmcg/core/theme/fscm_theme.dart';
import 'package:fmcg/features/sales/presentation/sales_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '0909 123 456');
  final _passwordController = TextEditingController(text: 'Fscm2026');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: FscmColors.primary,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'FSCM Sales',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Đặt hàng cho điểm bán, kể cả khi mất mạng.',
                    style: TextStyle(color: FscmColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('phoneField'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('passwordField'),
                    controller: _passwordController,
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
                    key: const Key('loginButton'),
                    onPressed: () =>
                        SalesScope.of(context, listen: false).login(),
                    child: const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'Chưa có mật khẩu?',
                          style: TextStyle(
                            color: FscmColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FirstLoginScreen(),
                      ),
                    ),
                    child: const Text('Đăng nhập lần đầu'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lần đầu cần có mạng để xác thực OTP, tạo mật khẩu và tải dữ liệu được phân quyền về máy.',
                    style: TextStyle(
                      color: FscmColors.muted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Nhập số điện thoại', 'Nhập mã xác thực', 'Tạo mật khẩu'];
    const descriptions = [
      'Dùng số điện thoại Admin đã khai báo cho tài khoản Sales.',
      'Mã OTP 6 số đã được gửi qua SMS và có hiệu lực trong 5 phút.',
      'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa và chữ số.',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập lần đầu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: index <= _step
                          ? FscmColors.primary
                          : FscmColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bước ${_step + 1}/3',
              style: const TextStyle(
                color: FscmColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              titles[_step],
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              descriptions[_step],
              style: const TextStyle(color: FscmColors.muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            if (_step == 0)
              const TextField(
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: '0909 123 456',
                ),
              ),
            if (_step == 1)
              const TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Mã OTP',
                  hintText: '482915',
                ),
              ),
            if (_step == 2) ...[
              const TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Mật khẩu mới'),
              ),
              const SizedBox(height: 14),
              const TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Nhập lại mật khẩu'),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () {
                if (_step < 2) {
                  setState(() => _step++);
                  return;
                }
                SalesScope.of(context, listen: false).login();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(
                _step == 2 ? 'Tạo mật khẩu và đăng nhập' : 'Tiếp tục',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
