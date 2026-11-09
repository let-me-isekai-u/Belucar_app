import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../utils/password_policy.dart';
import 'auth_ui.dart';
import 'login_screen.dart';
import 'terms_screen.dart';
import '../ui/ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _confirmPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  XFile? _avatar;
  String? _challengeId;
  Timer? _resendTimer;

  bool _agreeTerms = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _avatar = picked);
      }
    } catch (e) {
      _showSnack('Không thể chọn ảnh: $e');
    }
  }

  bool _validateForm() {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (_fullNameController.text.trim().isEmpty) {
      _showSnack('Họ tên không được để trống');
      return false;
    }

    if (email.length > 50 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showSnack('Email không hợp lệ');
      return false;
    }

    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone)) {
      _showSnack('Số điện thoại không hợp lệ');
      return false;
    }

    if (phone != _confirmPhoneController.text.trim()) {
      _showSnack('Số điện thoại nhập lại không trùng');
      return false;
    }

    final passwordError = newPasswordError(password);
    if (passwordError != null) {
      _showSnack(passwordError);
      return false;
    }

    if (password != _confirmPasswordController.text.trim()) {
      _showSnack('Mật khẩu nhập lại không trùng');
      return false;
    }

    if (!_agreeTerms) {
      _showSnack('Bạn cần đồng ý với Điều khoản sử dụng');
      return false;
    }

    return true;
  }

  Map<String, dynamic> _readResponse(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) return body;
    } on FormatException {
      // A proxy can return an HTML error page.
    }
    return {};
  }

  Future<void> _sendCode() async {
    if (_loading || (_resendTimer?.isActive ?? false) || !_validateForm()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final response = await ApiService.sendRegistrationCode(
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;

    final body = _readResponse(response);
    final challengeId = body['challengeId'];
    if (response.statusCode != 200 || challengeId is! String || challengeId.isEmpty) {
      setState(() => _loading = false);
      final message = body['message'];
      _showSnack(message is String ? message : 'Không gửi được mã xác minh. Vui lòng thử lại.');
      return;
    }

    _otpController.clear();
    setState(() {
      _loading = false;
      _challengeId = challengeId;
      _resendTimer = Timer(const Duration(minutes: 1), () {
        if (mounted) setState(() => _resendTimer = null);
      });
    });
  }

  Future<void> _handleRegister() async {
    final challengeId = _challengeId;
    if (_loading || challengeId == null) return;

    final otp = _otpController.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      _showSnack('Nhập mã xác minh gồm 6 chữ số.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final res = await ApiService.customerRegister(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      challengeId: challengeId,
      otp: otp,
      avatarFilePath: _avatar?.path ?? '',
      referredByCode: _referralCodeController.text.trim(),
    );

    if (!mounted) return;
    if (res.statusCode == 200 || res.statusCode == 201) {
      _showSnack('Đăng ký thành công!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() => _loading = false);
    final message = _readResponse(res)['message'];
    _showSnack(message is String ? message : 'Đăng ký thất bại (${res.statusCode})');
  }

  Widget _buildVerificationPanel() {
    final canResend = !(_resendTimer?.isActive ?? false);
    return AuthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xác minh email',
            style: TextStyle(color: Brand.ink, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhập mã 6 số đã gửi tới ${_emailController.text.trim()}. Mã có hiệu lực trong 10 phút.',
            style: const TextStyle(color: Brand.inkMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: authInputDecoration(
              context,
              label: 'Mã xác minh',
              icon: Icons.verified_outlined,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('ĐĂNG KÝ'),
          ),
          TextButton(
            onPressed: !_loading && canResend ? _sendCode : null,
            child: Text(canResend ? 'Gửi lại mã' : 'Có thể gửi lại sau 1 phút'),
          ),
          TextButton(
            onPressed: _loading ? null : () {
              _resendTimer?.cancel();
              _otpController.clear();
              setState(() {
                _resendTimer = null;
                _challengeId = null;
              });
            },
            child: const Text('Sửa thông tin đăng ký'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _confirmPhoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Brand.ink),
      decoration: authInputDecoration(context, label: label, icon: icon),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Brand.ink),
      decoration: authInputDecoration(
        context,
        label: label,
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Brand.navy,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    void backToLogin() => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );

    return AuthScaffold(
      bandHeight: 220,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: backToLogin,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Tạo tài khoản',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                          ),
                        ),
                        _AvatarPicker(path: _avatar?.path, onTap: _pickAvatar),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_challengeId != null)
                      _buildVerificationPanel()
                    else AuthPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _fullNameController,
                            label: 'Họ và tên',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Số điện thoại',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _confirmPhoneController,
                            label: 'Nhập lại số điện thoại',
                            icon: Icons.verified_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildPasswordField(
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            obscure: _obscurePassword,
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                            child: Text(
                              newPasswordHint,
                              style: TextStyle(color: Brand.inkMuted, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Nhập lại mật khẩu',
                            obscure: _obscureConfirmPassword,
                            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _referralCodeController,
                            label: 'Mã giới thiệu (nếu có)',
                            icon: Icons.card_giftcard_outlined,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Checkbox(
                                value: _agreeTerms,
                                activeColor: Brand.navy,
                                onChanged: (value) => setState(() => _agreeTerms = value ?? false),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                                  ),
                                  child: const Text.rich(
                                    TextSpan(
                                      style: TextStyle(color: Brand.inkMuted, fontSize: 14, height: 1.35),
                                      children: [
                                        TextSpan(text: 'Tôi đồng ý với '),
                                        TextSpan(
                                          text: 'Điều khoản sử dụng',
                                          style: TextStyle(color: Brand.navy, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _sendCode,
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('GỬI MÃ XÁC MINH'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: backToLogin,
                        child: const Text.rich(
                          TextSpan(
                            style: TextStyle(color: Brand.inkMuted, fontSize: 15),
                            children: [
                              TextSpan(text: 'Đã có tài khoản? '),
                              TextSpan(text: 'Đăng nhập', style: TextStyle(color: Brand.navy, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            Container(
              color: const Color(0x1A041565),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

/// Ảnh đại diện tuỳ chọn, đặt góc phải header.
class _AvatarPicker extends StatelessWidget {
  final String? path;
  final VoidCallback onTap;

  const _AvatarPicker({required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                image: path != null
                    ? DecorationImage(image: FileImage(File(path!)), fit: BoxFit.cover)
                    : null,
              ),
              child: path == null ? const Icon(Icons.person_outline_rounded, size: 30, color: Brand.b500) : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Brand.lane,
                  shape: BoxShape.circle,
                  border: Border.all(color: Brand.navy, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 12, color: Brand.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
