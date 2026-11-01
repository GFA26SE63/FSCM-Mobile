import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';

class RetailerActivationScreen extends ConsumerStatefulWidget {
  const RetailerActivationScreen({super.key});

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
    if (_phone.text.replaceAll(' ', '').length < 9) {
      setState(() => _error = 'Nhập số điện thoại hợp lệ.');
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
    final password = _password.text;
    final strongPassword = password.length >= 12 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[^A-Za-z0-9]'));
    if (!strongPassword) {
      setState(() => _error =
          'Mật khẩu tối thiểu 12 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }
    await _run(() async {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .completeActivation(_setupToken!, _password.text);
      if (!ok) {
        throw ApiException(
            kind: ApiErrorKind.validation,
            message: ref.read(authControllerProvider).error ??
                'Không thể kích hoạt tài khoản.');
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = ApiException.describe(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kích hoạt tài khoản')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(['Xác nhận tài khoản', 'Nhập OTP email', 'Tạo mật khẩu'][_step],
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(_step == 0
            ? 'Nhập số điện thoại đã được liên kết với tài khoản Retailer.'
            : _step == 1
                ? 'Kiểm tra email đã đăng ký. OTP có hiệu lực 5 phút.'
                : 'Tạo mật khẩu để hoàn tất kích hoạt.'),
        const SizedBox(height: 24),
        if (_step == 0)
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại')),
        if (_step == 1) ...[
          TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Mã OTP')),
          TextButton(
              onPressed: _busy ? null : () => launchUrl(Uri(scheme: 'mailto')),
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
          const SizedBox(height: 12),
          TextField(
              controller: _confirm,
              obscureText: _obscure,
              decoration:
                  const InputDecoration(labelText: 'Xác nhận mật khẩu')),
        ],
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 20),
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
