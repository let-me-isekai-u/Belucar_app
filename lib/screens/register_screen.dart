import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'auth_ui.dart';
import 'login_screen.dart';
import 'terms_screen.dart';

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

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return AuthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
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
      style: const TextStyle(color: Colors.white),
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
      style: const TextStyle(color: Colors.white),
      decoration: authInputDecoration(
        context,
        label: label,
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                    ),
                    AuthLogoHero(
                      title: 'Tạo tài khoản mới',
                      subtitle:
                          'Hoàn thiện thông tin một lần để dùng xuyên suốt cho đặt chuyến, ví và lịch sử hoạt động.',
                      assetPath: 'lib/assets/icons/dong_duong_logo.png',
                      trailing: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          AuthInfoChip(
                            icon: Icons.verified_user_outlined,
                            label: 'Thông tin rõ ràng',
                          ),
                          AuthInfoChip(
                            icon: Icons.support_agent_outlined,
                            label: 'Dễ hỗ trợ',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.secondary,
                                  width: 2,
                                ),
                                image: _avatar != null
                                    ? DecorationImage(
                                        image: FileImage(File(_avatar!.path)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: _avatar == null
                                  ? const Icon(
                                      Icons.person_outline_rounded,
                                      size: 42,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Ảnh đại diện là tuỳ chọn, chạm để thêm.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSection(
                      title: 'Thông tin cá nhân',
                      subtitle:
                          'Nhập chính xác để hệ thống và CSKH dễ đối chiếu.',
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Thông tin liên hệ',
                      subtitle:
                          'Số điện thoại sẽ được dùng cho đăng nhập và liên hệ.',
                      children: [
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Bảo mật',
                      subtitle:
                          'Mật khẩu cần có chữ hoa, chữ thường, số và ký tự đặc biệt.',
                      children: [
                        _buildPasswordField(
                          controller: _passwordController,
                          label: 'Mật khẩu',
                          obscure: _obscurePassword,
                          onToggle: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          label: 'Nhập lại mật khẩu',
                          obscure: _obscureConfirmPassword,
                          onToggle: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: 'Mã giới thiệu',
                      subtitle: 'Có thể bỏ qua nếu anh không có mã.',
                      children: [
                        _buildTextField(
                          controller: _referralCodeController,
                          label: 'Nhập mã giới thiệu',
                          icon: Icons.card_giftcard_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AuthPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _agreeTerms,
                                activeColor: theme.colorScheme.secondary,
                                onChanged: (value) {
                                  setState(() => _agreeTerms = value ?? false);
                                },
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const TermsScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Tôi đồng ý với Chính sách và Điều khoản sử dụng',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black87,
                                      ),
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
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 15,
                            ),
                            children: [
                              const TextSpan(text: 'Đã có tài khoản? '),
                              TextSpan(
                                text: 'Quay về đăng nhập',
                                style: TextStyle(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
              color: Colors.black.withValues(alpha: 0.22),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
