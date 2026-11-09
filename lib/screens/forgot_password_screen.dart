import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/password_policy.dart';
import 'account_ui.dart';
import 'login_screen.dart';
import '../ui/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSendingCode = false;
  bool _isResetting = false;
  bool _showPass = false;
  bool _showConfirmPass = false;
  int _countdown = 0;
  Timer? _timer;
  String? _challengeId;
  String? _challengeEmail;

  void _startCountdown() {
    _countdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
        setState(() {});
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _showSnack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Brand.ink)),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Vui lòng nhập email hợp lệ');
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final res = await ApiService.sendForgotPasswordOtp(email: email);
      if (!mounted) return;

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200 && body is Map && body['challengeId'] is String) {
        _challengeId = body['challengeId'] as String;
        _challengeEmail = email;
        _codeController.clear();
        _showSnack('Nếu email đã đăng ký, mã xác minh sẽ được gửi.', color: Colors.blue);
        _startCountdown();
      } else {
        _showSnack('Gửi mã thất bại');
      }
    } catch (_) {
      if (mounted) _showSnack('Không gửi được mã. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final challengeId = _challengeId;
    if (challengeId == null || _challengeEmail != email) {
      _showSnack('Vui lòng yêu cầu mã xác minh cho email này.');
      return;
    }

    setState(() => _isResetting = true);

    try {
      final res = await ApiService.resetPassword(
        email: email,
        challengeId: challengeId,
        otp: _codeController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        _showSnack('Đổi mật khẩu thành công!', color: Colors.green);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        _showSnack(body['message'] ?? 'Đổi mật khẩu thất bại');
      }
    } catch (e) {
      _showSnack('Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Quên mật khẩu',
          style: TextStyle(color: Brand.navy),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Brand.navy),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Brand.b50,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  size: 38,
                  color: Brand.navy,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Khôi phục quyền truy cập',
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhập email để nhận mã và đặt lại mật khẩu.',
                style: TextStyle(
                  color: Brand.inkMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              const AccountInfoBanner(
                text:
                    'Có thể gửi lại mã sau 30 giây.',
              ),
              const SizedBox(height: 18),
              AccountSectionCard(
                title: 'Xác thực email',
                icon: Icons.mark_email_unread_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Brand.ink),
                      decoration: accountInputDecoration(
                        context,
                        label: 'Email',
                        hint: 'Nhập email đăng ký',
                        icon: Icons.email_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        if (!v.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            style: const TextStyle(color: Brand.ink),
                            decoration: accountInputDecoration(
                              context,
                              label: 'Mã xác thực',
                              hint: 'Nhập OTP',
                              icon: Icons.lock_clock_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Nhập mã xác thực';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_isSendingCode || _isResetting || _countdown > 0)
                                ? null
                                : _sendCode,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            ),
                            child: _isSendingCode
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _countdown > 0 ? '$_countdown s' : 'Gửi mã',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AccountSectionCard(
                title: 'Mật khẩu mới',
                icon: Icons.password_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPass,
                      style: const TextStyle(color: Brand.ink),
                      decoration: accountInputDecoration(
                        context,
                        label: 'Mật khẩu mới',
                        hint: '8 ký tự trở lên',
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Brand.navy,
                          ),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),
                      validator: (v) => newPasswordError(v?.trim() ?? ''),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(newPasswordHint, style: TextStyle(color: Brand.inkMuted)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: !_showConfirmPass,
                      style: const TextStyle(color: Brand.ink),
                      decoration: accountInputDecoration(
                        context,
                        label: 'Nhập lại mật khẩu',
                        hint: 'Xác nhận mật khẩu',
                        icon: Icons.verified_user_outlined,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmPass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Brand.navy,
                          ),
                          onPressed: () => setState(
                            () => _showConfirmPass = !_showConfirmPass,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nhập lại mật khẩu';
                        if (v.trim() != _passwordController.text.trim()) {
                          return 'Mật khẩu không khớp';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isResetting || _isSendingCode ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: _isResetting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('ĐỔI MẬT KHẨU'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
