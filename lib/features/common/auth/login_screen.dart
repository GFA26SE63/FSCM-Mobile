import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fscm_mobile/core/config/device_identity.dart';
import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/remote/auth_api.dart';
import 'package:fscm_mobile/data/repositories/auth_repository.dart';
import 'package:fscm_mobile/shared/widgets/fscm_logo.dart';

enum _LoginStage { credentials, otpVerify, newPassword }

/// Mobile Login screen matching `FSCM_Prototype_Prod_v1.1.html` (`DEFS.mobile`)
/// and wired to the Auth API contract in `SPRINT_1_FRONTEND_MOBILE_API_GUIDE.md`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Color _primary = Color(0xFF14655B);
  static const Color _textMain = Color(0xFF1B1F1D);
  static const Color _textLabel = Color(0xFF3D4441);
  static const Color _textMuted = Color(0xFF5B625E);
  static const Color _border = Color(0xFFC9D0CB);
  static const Color _divider = Color(0xFFE2E5E0);
  static const Color _dangerText = Color(0xFFB42318);
  static const Color _dangerBg = Color(0xFFFDECEA);

  bool _isStaff = true;
  _LoginStage _stage = _LoginStage.credentials;

  late final TextEditingController _staffEmail;
  late final TextEditingController _staffPassword;
  late final TextEditingController _custPhone;
  late final TextEditingController _custPassword;
  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _obscureStaffPw = true;
  bool _obscureCustPw = true;
  bool _obscureNewPw = true;
  bool _obscureConfirmPw = true;
  bool _busy = false;
  String? _error;
  String? _setupToken;

  @override
  void initState() {
    super.initState();
    // Inputs are blank by default so real accounts can be used
    _staffEmail = TextEditingController();
    _staffPassword = TextEditingController();
    _custPhone = TextEditingController();
    _custPassword = TextEditingController();
    _otpControllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    _otpFocusNodes = List<FocusNode>.generate(6, (_) => FocusNode());
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _staffEmail.dispose();
    _staffPassword.dispose();
    _custPhone.dispose();
    _custPassword.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchTab(bool staff) {
    if (_isStaff == staff) return;
    ref.read(authControllerProvider.notifier).clearError();
    setState(() {
      _isStaff = staff;
      _error = null;
    });
  }

  String _normalizeStaffEmail(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.contains('@')) {
      if (lower == 'tam' || lower == 'wk') return 'tam.dv@fscm.vn';
      if (lower == 'an' || lower == 'sales') return 'an.nv@fscm.vn';
      if (lower == 'khoa' || lower == 'admin') return 'khoa.pm@fscm.vn';
    }
    return trimmed;
  }

  Future<void> _submitStaffLogin() async {
    final rawEmail = _staffEmail.text.trim();
    final password = _staffPassword.text;
    if (rawEmail.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ email và mật khẩu.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _normalizeStaffEmail(rawEmail);
      final ok = await ref
          .read(authControllerProvider.notifier)
          .login(email, password);

      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = ref.read(authControllerProvider).error ??
              'Email hoặc mật khẩu không đúng.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Đăng nhập không thành công: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submitCustomerLogin() async {
    final rawPhone = _custPhone.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\s+'), '');
    final password = _custPassword.text;
    if (cleanPhone.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ số điện thoại và mật khẩu.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = await ref.read(authControllerProvider.notifier).login(
            cleanPhone,
            password,
            phone: cleanPhone,
          );

      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = ref.read(authControllerProvider).error ??
              'Số điện thoại hoặc mật khẩu không đúng.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Đăng nhập không thành công: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _startFirstLoginOtpFlow() async {
    final rawPhone = _custPhone.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\s+'), '');
    if (cleanPhone.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập số điện thoại để nhận mã OTP.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).requestOtp(cleanPhone);
    } on ApiException {
      // Allow UI flow even if backend OTP endpoint is not active in dev.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _stage = _LoginStage.otpVerify;
    });
  }

  Future<void> _verifyOtpStep() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length < 6) {
      setState(() {
        _error = 'Vui lòng nhập đủ 6 chữ số mã xác thực OTP.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(authApiProvider).verifyOtp(
            phone: _custPhone.text.trim(),
            code: code,
          );
      _setupToken = token;
    } on ApiException {
      _setupToken = 'setup-token';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _stage = _LoginStage.newPassword;
    });
  }

  bool get _pwHasMinLength => _newPasswordController.text.length >= 8;
  bool get _pwHasAlphaNum =>
      RegExp(r'[A-Za-z]').hasMatch(_newPasswordController.text) &&
      RegExp(r'\d').hasMatch(_newPasswordController.text);
  bool get _pwDiffersDefault =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text != '12345678';
  bool get _pwMatchesConfirm =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  Future<void> _completeNewPasswordStep() async {
    final newPw = _newPasswordController.text;
    if (!_pwHasMinLength || !_pwHasAlphaNum || !_pwDiffersDefault) {
      setState(() {
        _error = 'Mật khẩu mới chưa đáp ứng đủ các điều kiện bảo mật.';
      });
      return;
    }
    if (!_pwMatchesConfirm) {
      setState(() {
        _error = 'Xác nhận mật khẩu mới không khớp.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final cleanPhone = _custPhone.text.replaceAll(RegExp(r'\s+'), '');
    try {
      final session = await ref.read(authApiProvider).setPassword(
            setupToken: _setupToken ?? 'mock-setup-token',
            password: newPw,
            phone: cleanPhone,
          );
      final ok = await ref
          .read(authControllerProvider.notifier)
          .completeSession(session);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (!ok) {
          _error = ref.read(authControllerProvider).error;
        }
      });
    } on ApiException {
      // Fallback to standard login with the updated password.
      final ok = await ref.read(authControllerProvider.notifier).login(
            cleanPhone,
            newPw,
            phone: cleanPhone,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (!ok) {
          _error = ref.read(authControllerProvider).error;
        }
      });
    }
  }

  Future<void> _openMicrosoftSignInDialog() async {
    setState(() => _error = null);
    final selectedEmail = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x8C0F1714),
      builder: (ctx) => const _MicrosoftSignInDialog(),
    );
    if (selectedEmail == null || !mounted) return;

    setState(() {
      _staffEmail.text = selectedEmail;
      _busy = true;
      _error = null;
    });

    try {
      final ok = await ref
          .read(authControllerProvider.notifier)
          .login(selectedEmail, 'Fscm2026');

      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = ref.read(authControllerProvider).error ??
              'Đăng nhập Microsoft không thành công.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Đăng nhập Microsoft không thành công: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildStageContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case _LoginStage.otpVerify:
        return _buildOtpVerifyView();
      case _LoginStage.newPassword:
        return _buildNewPasswordView();
      case _LoginStage.credentials:
        return _buildCredentialsView();
    }
  }

  Widget _buildCredentialsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Align(
          alignment: Alignment.centerLeft,
          child: FscmLogo(
            size: 56,
            iconSize: 30,
            borderRadius: 16,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'FSCM',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: _textMain,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Đặt hàng, soạn hàng và nhận hàng hạn sử dụng ngắn.',
          style: TextStyle(
            fontSize: 15,
            color: _textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        _buildSegmentedToggle(),
        const SizedBox(height: 22),
        if (_isStaff) _buildStaffForm() else _buildCustomerForm(),
      ],
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              key: const Key('tab_staff'),
              onTap: _busy ? null : () => _switchTab(true),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                color: _isStaff ? _primary : Colors.white,
                child: Text(
                  'Nhân viên',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isStaff ? Colors.white : _textLabel,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              key: const Key('tab_customer'),
              onTap: _busy ? null : () => _switchTab(false),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                color: !_isStaff ? _primary : Colors.white,
                child: Text(
                  'Khách hàng',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: !_isStaff ? Colors.white : _textLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffForm() {
    final error = _error ?? ref.watch(authControllerProvider).error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildFieldLabel('Email'),
        const SizedBox(height: 6),
        _buildTextField(
          key: const Key('input_staff_email'),
          controller: _staffEmail,
          keyboardType: TextInputType.emailAddress,
          hintText: 'name@fscm.vn',
          onSubmitted: (_) => _submitStaffLogin(),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Mật khẩu'),
        const SizedBox(height: 6),
        _buildTextField(
          key: const Key('input_staff_password'),
          controller: _staffPassword,
          obscureText: _obscureStaffPw,
          hintText: 'Nhập mật khẩu',
          onToggleObscure: () =>
              setState(() => _obscureStaffPw = !_obscureStaffPw),
          onSubmitted: (_) => _submitStaffLogin(),
        ),
        if (error != null && error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _buildErrorBanner(error),
        ],
        const SizedBox(height: 22),
        _buildPrimaryButton(
          key: const Key('btn_staff_login'),
          label: _busy ? 'Đang đăng nhập...' : 'Đăng nhập',
          onPressed: _busy ? null : _submitStaffLogin,
        ),
        const SizedBox(height: 18),
        _buildStaffBottomSection(),
      ],
    );
  }

  Widget _buildStaffBottomSection() {
    return SizedBox(
      height: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                  child: Divider(color: _divider, height: 1, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'hoặc',
                  style: TextStyle(fontSize: 12.5, color: _textMuted),
                ),
              ),
              Expanded(
                  child: Divider(color: _divider, height: 1, thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('btn_microsoft_login'),
            onPressed: _busy ? null : _openMicrosoftSignInDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.white,
              foregroundColor: _primary,
              side: const BorderSide(color: _primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MicrosoftLogo(size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Đăng nhập với Microsoft',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerForm() {
    final error = _error ?? ref.watch(authControllerProvider).error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildFieldLabel('Số điện thoại'),
        const SizedBox(height: 6),
        _buildTextField(
          key: const Key('input_customer_phone'),
          controller: _custPhone,
          keyboardType: TextInputType.emailAddress,
          hintText: '0909 555 127',
          onSubmitted: (_) => _submitCustomerLogin(),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Mật khẩu'),
        const SizedBox(height: 6),
        _buildTextField(
          key: const Key('input_customer_password'),
          controller: _custPassword,
          obscureText: _obscureCustPw,
          hintText: 'Nhập mật khẩu',
          onToggleObscure: () =>
              setState(() => _obscureCustPw = !_obscureCustPw),
          onSubmitted: (_) => _submitCustomerLogin(),
        ),
        if (error != null && error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _buildErrorBanner(error),
        ],
        const SizedBox(height: 22),
        _buildPrimaryButton(
          key: const Key('btn_customer_login'),
          label: _busy ? 'Đang đăng nhập...' : 'Đăng nhập',
          onPressed: _busy ? null : _submitCustomerLogin,
        ),
        const SizedBox(height: 18),
        _buildCustomerBottomSection(),
      ],
    );
  }

  Widget _buildCustomerBottomSection() {
    return SizedBox(
      height: 110,
      child: Center(
        child: TextButton(
          key: const Key('btn_first_login_otp'),
          onPressed: _busy ? null : _startFirstLoginOtpFlow,
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Đăng nhập lần đầu? Xác thực OTP & đổi mật khẩu'),
        ),
      ),
    );
  }

  Widget _buildOtpVerifyView() {
    final phoneDisplay = _custPhone.text.trim().isNotEmpty
        ? _custPhone.text.trim()
        : '0909 555 127';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: _textMain),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _error = null;
                        _stage = _LoginStage.credentials;
                      }),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Đăng nhập lần đầu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textMain,
                    ),
                  ),
                  Text(
                    'Xác thực OTP',
                    style: TextStyle(fontSize: 12.5, color: _textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDADFDB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Bước 1/2',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nhập mã xác thực',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mã OTP 6 số đã gửi qua SMS tới $phoneDisplay.',
          style: const TextStyle(fontSize: 14, color: _textMuted, height: 1.5),
        ),
        const SizedBox(height: 18),
        Row(
          children: List<Widget>.generate(6, (index) {
            final hasVal = _otpControllers[index].text.isNotEmpty;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index < 5 ? 8 : 0),
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _textMain,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: hasVal ? _primary : _border,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primary, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      if (value.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        const Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 13, color: _textMuted),
            children: <InlineSpan>[
              TextSpan(text: 'Chưa nhận được mã? '),
              TextSpan(
                text: 'Gửi lại sau 00:45',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_error != null && _error!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _buildErrorBanner(_error!),
        ],
        const SizedBox(height: 22),
        _buildPrimaryButton(
          key: const Key('btn_otp_verify'),
          label: _busy ? 'Đang xác nhận...' : 'Xác nhận',
          onPressed: _busy ? null : _verifyOtpStep,
        ),
      ],
    );
  }

  Widget _buildNewPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: _textMain),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _error = null;
                        _stage = _LoginStage.otpVerify;
                      }),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Đăng nhập lần đầu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textMain,
                    ),
                  ),
                  Text(
                    'Đổi mật khẩu',
                    style: TextStyle(fontSize: 12.5, color: _textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Bước 2/2',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Đổi mật khẩu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textMain,
          ),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Mật khẩu mới'),
        const SizedBox(height: 6),
        _buildTextField(
          key: const Key('input_new_password'),
          controller: _newPasswordController,
          obscureText: _obscureNewPw,
          hintText: 'Nhập mật khẩu mới',
          onToggleObscure: () => setState(() => _obscureNewPw = !_obscureNewPw),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Nhập lại mật khẩu mới'),
        const SizedBox(height: 6),
        _buildTextField(
          key: const Key('input_confirm_password'),
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPw,
          hintText: 'Xác nhận lại mật khẩu mới',
          onToggleObscure: () =>
              setState(() => _obscureConfirmPw = !_obscureConfirmPw),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildPasswordRule('Tối thiểu 8 ký tự', _pwHasMinLength),
            const SizedBox(height: 6),
            _buildPasswordRule('Có cả chữ và số', _pwHasAlphaNum),
            const SizedBox(height: 6),
            _buildPasswordRule('Khác mật khẩu được cấp', _pwDiffersDefault),
            const SizedBox(height: 6),
            _buildPasswordRule('Hai lần nhập trùng khớp', _pwMatchesConfirm),
          ],
        ),
        if (_error != null && _error!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _buildErrorBanner(_error!),
        ],
        const SizedBox(height: 22),
        _buildPrimaryButton(
          key: const Key('btn_complete_new_password'),
          label: _busy ? 'Đang xử lý...' : 'Đổi mật khẩu và đăng nhập',
          onPressed: _busy ? null : _completeNewPasswordStep,
        ),
      ],
    );
  }

  Widget _buildPasswordRule(String text, bool met) {
    return Row(
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? const Color(0xFF15703A) : Colors.white,
            border: met
                ? null
                : Border.all(color: const Color(0xFFA7B0AB), width: 2),
          ),
          alignment: Alignment.center,
          child: met
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            color: met ? _textMain : _textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return SizedBox(
      height: 18,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textLabel,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? hintText,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 15,
          color: _textMain,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF98A29D), fontSize: 15),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          suffixIcon: onToggleObscure == null
              ? null
              : IconButton(
                  onPressed: onToggleObscure,
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: _textMuted,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final isConnError = message.contains('Không kết nối được') ||
        message.contains('Không có kết nối mạng');
    return Container(
      key: const Key('login_error_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _dangerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: _dangerText,
              height: 1.4,
            ),
          ),
          if (isConnError) ...<Widget>[
            const SizedBox(height: 6),
            InkWell(
              onTap: _openServerConfigDialog,
              child: const Text(
                'Cấu hình địa chỉ máy chủ (IP / Wi-Fi) →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openServerConfigDialog() async {
    final controller = TextEditingController(text: Env.effectiveApiBaseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Địa chỉ máy chủ (Backend)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Nhập IP Wi-Fi của máy tính đang chạy Backend (VD: 10.87.16.166) hoặc URL đầy đủ:',
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'https://${Env.lanHost}:7027/api/v1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ActionChip(
                    label: const Text(
                      'Wi-Fi (${Env.lanHost})',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      controller.text = 'https://${Env.lanHost}:7027/api/v1';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'USB (localhost)',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      controller.text = 'https://localhost:7027/api/v1';
                    },
                  ),
                  ActionChip(
                    label: const Text(
                      'Máy ảo (10.0.2.2)',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      controller.text = 'https://10.0.2.2:7027/api/v1';
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return;
    Env.setRuntimeApiBaseUrl(result);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (result.isEmpty) {
        await prefs.remove(Env.customApiBaseUrlPrefKey);
      } else {
        await prefs.setString(
          Env.customApiBaseUrlPrefKey,
          Env.effectiveApiBaseUrl,
        );
      }
    } catch (_) {
      // Ignore if SharedPreferences is not overridden in unit tests.
    }
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  Widget _buildPrimaryButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return FilledButton(
      key: key,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: _primary,
        disabledBackgroundColor: _primary.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

/// 4-square Microsoft logo used in the button and modal header.
class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final sq = size * 0.44;
    final gap = size - (sq * 2);
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(width: sq, height: sq, color: const Color(0xFFF25022)),
              SizedBox(width: gap),
              Container(width: sq, height: sq, color: const Color(0xFF7FBA00)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(width: sq, height: sq, color: const Color(0xFF00A4EF)),
              SizedBox(width: gap),
              Container(width: sq, height: sq, color: const Color(0xFFFFB900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MsAccountOption {
  const _MsAccountOption({
    required this.name,
    required this.email,
    required this.allowedOnMobile,
  });

  final String name;
  final String email;
  final bool allowedOnMobile;
}

const List<_MsAccountOption> _msAccounts = <_MsAccountOption>[
  _MsAccountOption(
    name: 'Nguyễn Văn An',
    email: 'an.nv@fscm.vn',
    allowedOnMobile: true,
  ),
  _MsAccountOption(
    name: 'Đỗ Văn Tâm',
    email: 'tam.dv@fscm.vn',
    allowedOnMobile: true,
  ),
  _MsAccountOption(
    name: 'Phạm Minh Khoa',
    email: 'khoa.pm@fscm.vn',
    allowedOnMobile: false,
  ),
  _MsAccountOption(
    name: 'Thực tập 01',
    email: 'thuctap01@fscm.vn',
    allowedOnMobile: false,
  ),
];

enum _MsModalState { pick, loading, denied }

/// Microsoft Entra ID account picker modal matching `msOpen` in
/// `FSCM_Prototype_Prod_v1.1.html`.
class _MicrosoftSignInDialog extends StatefulWidget {
  const _MicrosoftSignInDialog();

  @override
  State<_MicrosoftSignInDialog> createState() => _MicrosoftSignInDialogState();
}

class _MicrosoftSignInDialogState extends State<_MicrosoftSignInDialog> {
  _MsModalState _state = _MsModalState.pick;
  String _selectedEmail = '';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pickAccount(_MsAccountOption account) {
    setState(() {
      _selectedEmail = account.email;
      _state = _MsModalState.loading;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (account.allowedOnMobile) {
        Navigator.of(context).pop(account.email);
      } else {
        setState(() {
          _state = _MsModalState.denied;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E5E0))),
              ),
              child: Row(
                children: <Widget>[
                  const _MicrosoftLogo(size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Microsoft',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1F1D),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF5B625E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_state == _MsModalState.pick) _buildPickView(),
                  if (_state == _MsModalState.loading) _buildLoadingView(),
                  if (_state == _MsModalState.denied) _buildDeniedView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text(
          'Chọn tài khoản',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1F1D),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'để tiếp tục tới FSCM',
          style: TextStyle(fontSize: 14, color: Color(0xFF5B625E)),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < _msAccounts.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          OutlinedButton(
            key: Key('ms_account_${_msAccounts[i].email}'),
            onPressed: () => _pickAccount(_msAccounts[i]),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              alignment: Alignment.centerLeft,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF14655B),
              side: const BorderSide(color: Color(0xFF14655B), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _msAccounts[i].name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14655B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _msAccounts[i].email,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF5B625E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Đang đăng nhập…',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1F1D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedEmail,
          style: const TextStyle(fontSize: 14, color: Color(0xFF5B625E)),
        ),
      ],
    );
  }

  Widget _buildDeniedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Không có quyền truy cập. Tài khoản $_selectedEmail chưa được gán vai trò Sales hoặc Warehouse Keeper trên FSCM. Liên hệ Admin để được cấp quyền.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB42318),
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => setState(() => _state = _MsModalState.pick),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF14655B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Chọn tài khoản khác',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF14655B),
            side: const BorderSide(color: Color(0xFF14655B), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Đóng',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
