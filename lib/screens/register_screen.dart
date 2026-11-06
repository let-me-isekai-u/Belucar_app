import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
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

  XFile? _avatar;

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
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    final phoneRegex = RegExp(r'^[0-9]{9,11}$');
    final strongPassRegex = RegExp(
      r'''^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[~!@#$%^&*()_+=<>?:";'{}|\\[\]])[A-Za-z\d~!@#$%^&*()_+=<>?:";'{}|\\[\]]{8,32}$''',
    );

    if (_fullNameController.text.trim().isEmpty) {
      _showSnack('Họ tên không được để trống');
      return false;
    }

    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnack('Email không hợp lệ');
      return false;
    }

    if (!phoneRegex.hasMatch(_phoneController.text.trim())) {
      _showSnack('Số điện thoại không hợp lệ');
      return false;
    }

    if (_phoneController.text.trim() != _confirmPhoneController.text.trim()) {
      _showSnack('Số điện thoại nhập lại không trùng');
      return false;
    }

    if (!strongPassRegex.hasMatch(_passwordController.text.trim())) {
      _showSnack(
        'Mật khẩu quá yếu (phải gồm chữ hoa, chữ thường, số, ký tự đặc biệt)',
      );
      return false;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showSnack('Mật khẩu nhập lại không trùng');
      return false;
    }

    if (!_agreeTerms) {
      _showSnack('Bạn cần đồng ý với Điều khoản sử dụng');
      return false;
    }

    return true;
  }

  Future<void> _handleRegister() async {
    if (!_validateForm()) return;

    setState(() => _loading = true);

    final res = await ApiService.customerRegister(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      avatarFilePath: _avatar?.path ?? '',
      referredByCode: _referralCodeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.statusCode == 200 || res.statusCode == 201) {
      _showSnack('Đăng ký thành công!');
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return;
    }

    try {
      final json = jsonDecode(res.body);
      _showSnack(json['message'] ?? 'Lỗi đăng ký');
    } catch (_) {
      _showSnack('Đăng ký thất bại (${res.statusCode})');
    }
  }

  @override
  void dispose() {
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
                    AuthPanel(
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
                              'Gồm chữ hoa, chữ thường, số và ký tự đặc biệt',
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
                              onPressed: _loading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('ĐĂNG KÝ'),
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
