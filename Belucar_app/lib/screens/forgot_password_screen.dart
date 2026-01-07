import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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

  /// NEW: show/hide password flags
  bool _showPass = false;
  bool _showConfirmPass = false;

  /// NEW: countdown
  int _countdown = 0;
  Timer? _timer;

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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  /// GỬI MÃ OTP
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains("@")) {
      _showSnack("Vui lòng nhập email hợp lệ");
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      final res = await ApiService.sendForgotPasswordOtp(email: email);

      if (res.statusCode == 200) {
        _showSnack("Đã gửi mã xác thực!", color: Colors.blue);
        _startCountdown(); // NEW
      } else {
        _showSnack("Gửi mã thất bại");
      }
    } catch (e) {
      _showSnack("Lỗi kết nối: $e");
    } finally {
      setState(() => _isSendingCode = false);
    }
  }

  /// ĐỔI MẬT KHẨU
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isResetting = true);

    try {
      final res = await ApiService.resetPassword(
        email: _emailController.text.trim(),
        otp: _codeController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );

      if (res.statusCode == 200) {
        _showSnack("Đổi mật khẩu thành công!", color: Colors.green);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        _showSnack(body["message"] ?? "Đổi mật khẩu thất bại");
      }
    } catch (e) {
      _showSnack("Lỗi kết nối: $e");
    } finally {
      setState(() => _isResetting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quên mật khẩu"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                /// EMAIL
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Vui lòng nhập email";
                    if (!v.contains("@")) return "Email không hợp lệ";
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                /// OTP + GỬI MÃ
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: "Mã xác thực",
                          prefixIcon: Icon(Icons.lock_clock_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Nhập mã xác thực";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: (_isSendingCode || _countdown > 0)
                          ? null
                          : _sendCode,
                      child: _isSendingCode
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(_countdown > 0 ? "$_countdown s" : "Gửi mã"),
                    )
                  ],
                ),

                const SizedBox(height: 18),

                /// MẬT KHẨU MỚI
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    labelText: "Mật khẩu mới",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_showPass
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _showPass = !_showPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Nhập mật khẩu mới";
                    if (v.length < 6) return "Mật khẩu tối thiểu 6 ký tự";
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                /// NHẬP LẠI MẬT KHẨU
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_showConfirmPass,
                  decoration: InputDecoration(
                    labelText: "Nhập lại mật khẩu",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirmPass
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                              () => _showConfirmPass = !_showConfirmPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Nhập lại mật khẩu";
                    if (v != _passwordController.text.trim()) {
                      return "Mật khẩu không khớp";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                /// NÚT ĐỔI MẬT KHẨU
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isResetting ? null : _resetPassword,
                    child: _isResetting
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ))
                        : const Text("Đổi mật khẩu"),
                  ),
                ),

                const SizedBox(height: 12),

                /// BACK TO LOGIN
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: Text(
                    "Quay về đăng nhập",
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
