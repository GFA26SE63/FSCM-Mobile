import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/routes.dart';

/// Phone + password or Google login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(_phone.text.replaceAll(' ', ''), _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = ref.read(authControllerProvider).error;
    });
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok =
        await ref.read(authControllerProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = ref.read(authControllerProvider).error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.ac_unit,
                        size: 44, color: AppColors.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'FSCM',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Đặt hàng, giao nhận và theo dõi hàng tươi ngắn hạn - kể cả khi mất mạng.',
                      style: TextStyle(color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Số điện thoại'),
                      validator: (v) =>
                          (v == null || v.replaceAll(' ', '').length < 9)
                              ? 'Nhập số điện thoại'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      InfoBanner(
                          text: _error!,
                          tone: StatusTone.danger,
                          icon: Icons.error_outline),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Đang đăng nhập...' : 'Đăng nhập'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.push(AppRoutes.retailerActivation),
                      child: const Text('Kích hoạt tài khoản Retailer lần đầu'),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: <Widget>[
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('hoặc'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _submitGoogle,
                      icon: const Icon(Icons.login),
                      label: const Text('Đăng nhập bằng Google'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tài khoản do nhà phân phối / Admin cấp. Vai trò (Sales, Thủ kho, Điểm bán) '
                      'được xác định theo tài khoản.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
