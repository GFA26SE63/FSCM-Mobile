import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/routes.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';

/// Phone + password or Google login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  bool _passwordStep = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final identifier = _identifier.text.trim();
    var ok = true;
    try {
      if (!_passwordStep) {
        final firstLogin = await ref
            .read(authControllerProvider.notifier)
            .requiresActivation(identifier);
        if (!mounted) return;
        if (firstLogin) {
          await context.push(AppRoutes.retailerActivation, extra: identifier);
          return;
        }
        setState(() => _passwordStep = true);
        return;
      }
      ok = await ref
          .read(authControllerProvider.notifier)
          .login(identifier, _password.text.trim());
    } on ApiException catch (error) {
      if (error.code == 'retailer_activation_required' && mounted) {
        await context.push(AppRoutes.retailerActivation, extra: identifier);
        return;
      }
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          if (_passwordStep && _error == null && !ok) {
            _error = ref.read(authControllerProvider).error;
          }
        });
      }
    }
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
    final authError = _error ?? ref.watch(authControllerProvider).error;
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
                      controller: _identifier,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: 'Email hoặc Số điện thoại'),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        final isEmail =
                            RegExp(r'^\S+@\S+\.\S+$').hasMatch(value);
                        final isPhone = RegExp(r'^0\d{9}$')
                            .hasMatch(value.replaceAll(' ', ''));
                        return isEmail || isPhone
                            ? null
                            : 'Nhập email hoặc số điện thoại hợp lệ';
                      },
                    ),
                    if (_passwordStep) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (authError != null)
                      InfoBanner(
                          text: authError,
                          tone: StatusTone.danger,
                          icon: Icons.error_outline),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy
                          ? 'Đang xử lý...'
                          : (_passwordStep ? 'Đăng nhập' : 'Tiếp tục')),
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
                      icon: Image.asset(
                        'assets/images/google_g_logo.png',
                        width: 20,
                        height: 20,
                      ),
                      label: const Text('Đăng nhập bằng Google'),
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
