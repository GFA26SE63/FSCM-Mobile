import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fscm_mobile/core/utils/status_tone.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/theme/app_colors.dart';
import 'package:fscm_mobile/shared/theme/app_text.dart';
import 'package:fscm_mobile/shared/theme/app_tokens.dart';
import 'package:fscm_mobile/shared/widgets/info_banner.dart';
import 'package:fscm_mobile/shared/widgets/password_requirements.dart';

class RetailerActivationScreen extends ConsumerStatefulWidget {
  const RetailerActivationScreen({super.key, this.identifier});
  final String? identifier;

  @override
  ConsumerState<RetailerActivationScreen> createState() =>
      _RetailerActivationScreenState();
}

class _RetailerActivationScreenState
    extends ConsumerState<RetailerActivationScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 0;
  int _resendSeconds = 0;
  bool _busy = false;
  bool _obscure = true;
  String? _setupToken;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.identifier != null) {
      _phone.text = widget.identifier!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestOtp());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _requestOtp() async {
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Nhập Email hoặc số điện thoại hợp lệ.');
      return;
    }
    await _run(() async {
      await ref
          .read(authControllerProvider.notifier)
          .requestActivationOtp(_phone.text.replaceAll(' ', ''));
      if (mounted) {
        setState(() => _step = 1);
        _startCooldown();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_otp.text.trim())) {
      setState(() => _error = 'OTP phải gồm đúng 6 chữ số.');
      return;
    }
    await _run(() async {
      final token = await ref
          .read(authControllerProvider.notifier)
          .verifyActivationOtp(
              _phone.text.replaceAll(' ', ''), _otp.text.trim());
      if (mounted) {
        setState(() {
          _setupToken = token;
          _step = 2;
        });
      }
    });
  }

  Future<void> _setPassword() async {
    final password = _password.text.trim();
    if (!PasswordPolicy.isValid(password)) {
      setState(() =>
          _error = 'Mật khẩu chưa đạt đủ các yêu cầu bên dưới ô mật khẩu.');
      return;
    }
    if (password != _confirm.text.trim()) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }
    await _run(() async {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .completeActivation(_setupToken!, password);
      if (!ok) return;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object {
      // API failures are already shown once by the root snackbar. `_error`
      // is reserved for client-side validation so the same error is not shown twice.
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  static const List<String> _titles = <String>[
    'Xác nhận tài khoản',
    'Nhập OTP email',
    'Tạo mật khẩu',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Kích hoạt tài khoản')),
      body: SafeArea(
          child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
            _StepProgress(step: _step, total: _titles.length),
            const SizedBox(height: AppSpacing.lg),
            Text(_titles[_step],
                style: AppText.display.copyWith(color: AppColors.text)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _step == 0
                  ? 'Nhập số điện thoại đã được liên kết với tài khoản điểm bán.'
                  : _step == 1
                      ? 'Kiểm tra email đã đăng ký. OTP có hiệu lực 5 phút.'
                      : 'Tạo mật khẩu để hoàn tất kích hoạt.',
              style: AppText.bodyMedium
                  .copyWith(color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_step == 0)
              TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Số điện thoại')),
            if (_step == 1) ...[
              TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppText.display
                      .copyWith(letterSpacing: 8, color: AppColors.text),
                  decoration: const InputDecoration(labelText: 'Mã OTP')),
              TextButton(
                  onPressed:
                      _busy ? null : () => launchUrl(Uri(scheme: 'mailto')),
                  child: const Text('Mở ứng dụng email')),
              TextButton(
                  onPressed: _busy || _resendSeconds > 0 ? null : _requestOtp,
                  child: Text(_resendSeconds > 0
                      ? 'Gửi lại sau $_resendSeconds giây'
                      : 'Gửi lại OTP')),
            ],
            if (_step == 2) ...[
              TextField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                      labelText: 'Mật khẩu mới',
                      suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility)))),
              const SizedBox(height: AppSpacing.sm),
              // Same trimmed value that _setPassword submits, so a tick always means "accepted".
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _password,
                builder: (context, value, _) =>
                    PasswordRequirementsChecklist(password: value.text.trim()),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                  controller: _confirm,
                  obscureText: _obscure,
                  decoration:
                      const InputDecoration(labelText: 'Xác nhận mật khẩu')),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: InfoBanner(
                      text: _error!,
                      tone: StatusTone.danger,
                      icon: Icons.error_outline)),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
                onPressed: _busy
                    ? null
                    : (_step == 0
                        ? _requestOtp
                        : _step == 1
                            ? _verifyOtp
                            : _setPassword),
                child: Text(_busy
                    ? 'Đang xử lý...'
                    : (_step == 0
                        ? 'Gửi OTP'
                        : _step == 1
                            ? 'Xác minh OTP'
                            : 'Tạo mật khẩu'))),
            if (_step > 0)
              TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _step--;
                            _error = null;
                          }),
                  child: const Text('Quay lại')),
            TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: const Text('Về đăng nhập')),
          ])),
    );
  }
}

/// 3-segment progress bar and "Bước n/3" label (prototype step indicator).
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var i = 0; i < total; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Bước ${step + 1}/$total',
            style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
