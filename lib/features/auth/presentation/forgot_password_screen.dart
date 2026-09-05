import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

enum _Step { email, otp, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = Supabase.instance.client.auth;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _pwController = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  int _resendCountdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('請輸入有效的 Email');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.resetPasswordForEmail(email);
      _startCountdown();
      setState(() => _step = _Step.otp);
    } on AuthException {
      _showError('寄送失敗，請稍後再試（免費方案每小時發信數有限）');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      _showError('請輸入信中的 6 位驗證碼');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.verifyOTP(
        type: OtpType.recovery,
        email: _emailController.text.trim(),
        token: token,
      );
      setState(() => _step = _Step.password);
    } on AuthException {
      _showError('驗證碼錯誤或已過期');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setNewPassword() async {
    final pw = _pwController.text;
    if (pw.length < 6) {
      _showError('密碼至少需要 6 碼');
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('密碼已重設')));
      context.go('/swipe'); // verifyOTP 成功後已有 session
    } on AuthException catch (e) {
      _showError('重設失敗：${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('忘記密碼')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: switch (_step) {
          _Step.email => _buildStep(
              hint: '輸入註冊時使用的 Email，我們會寄送 6 位驗證碼給你。',
              field: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              buttonLabel: '寄送驗證碼',
              onPressed: _sendEmail,
            ),
          _Step.otp => _buildStep(
              hint: '驗證碼已寄到 ${_emailController.text.trim()}',
              field: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '6 位驗證碼'),
              ),
              buttonLabel: '驗證',
              onPressed: _verifyOtp,
              extra: TextButton(
                onPressed: _resendCountdown > 0 || _busy ? null : _sendEmail,
                child: Text(_resendCountdown > 0
                    ? '重新寄送（$_resendCountdown s）'
                    : '重新寄送'),
              ),
            ),
          _Step.password => _buildStep(
              hint: '驗證成功，請設定新密碼。',
              field: TextField(
                controller: _pwController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密碼（至少 6 碼）'),
              ),
              buttonLabel: '完成重設',
              onPressed: _setNewPassword,
            ),
        },
      ),
    );
  }

  Widget _buildStep({
    required String hint,
    required Widget field,
    required String buttonLabel,
    required VoidCallback onPressed,
    Widget? extra,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(hint, style: TextStyle(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
        field,
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : onPressed,
          child: _busy
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(buttonLabel),
        ),
        if (extra != null) extra,
      ],
    );
  }
}
