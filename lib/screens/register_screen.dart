import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'terms_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'dart:convert';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _avatar = picked);
      }
    } catch (e) {
      _showSnack("Không thể chọn ảnh: $e");
    }
  }

  bool _validateForm() {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    final phoneRegex = RegExp(r'^[0-9]{9,11}$');
    final strongPassRegex = RegExp(
        r'''^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[~!@#$%^&*()_+=<>?:";'{}|\\[\]])[A-Za-z\d~!@#$%^&*()_+=<>?:";'{}|\\[\]]{8,32}$'''
    );


    if (_fullNameController.text.trim().isEmpty) {
      _showSnack("Họ tên không được để trống");
      return false;
    }

    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnack("Email không hợp lệ");
      return false;
    }

    if (!phoneRegex.hasMatch(_phoneController.text.trim())) {
      _showSnack("Số điện thoại không hợp lệ");
      return false;
    }

    if (_phoneController.text.trim() != _confirmPhoneController.text.trim()) {
      _showSnack("Số điện thoại nhập lại không trùng");
      return false;
    }

    if (!strongPassRegex.hasMatch(_passwordController.text.trim())) {
      _showSnack(
          "Mật khẩu quá yếu (phải gồm chữ hoa, chữ thường, số, ký tự đặc biệt)");
      return false;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showSnack("Mật khẩu nhập lại không trùng");
      return false;
    }

    if (!_agreeTerms) {
      _showSnack("Bạn cần đồng ý với Điều khoản sử dụng");
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
      avatarFilePath: _avatar?.path ?? "",
      referredByCode: _referralCodeController.text.trim(),
    );

    setState(() => _loading = false);

    if (res.statusCode == 200 || res.statusCode == 201) {
      _showSnack("Đăng ký thành công!");
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      });
    } else {
      try {
        final json = jsonDecode(res.body);
        _showSnack(json["message"] ?? "Lỗi đăng ký");
      } catch (_) {
        _showSnack("Đăng ký thất bại (${res.statusCode})");
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Đăng ký Tài khoản",
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // 1. ẢNH AVATAR
                  _buildAvatarSection(theme),
                  const SizedBox(height: 24),

                  // 2. NHÓM THÔNG TIN CÁ NHÂN
                  _buildInfoCard(
                    theme: theme,
                    title: "Thông tin cá nhân",
                    children: [
                      _buildTextField(_fullNameController, "Họ và tên", Icons.badge, false, false, theme),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, "Email", Icons.email, false, false, theme),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. NHÓM THÔNG TIN LIÊN HỆ
                  _buildInfoCard(
                    theme: theme,
                    title: "Thông tin liên hệ",
                    children: [
                      _buildTextField(_phoneController, "Số điện thoại", Icons.phone, false, true, theme),
                      const SizedBox(height: 16),
                      _buildTextField(_confirmPhoneController, "Nhập lại số điện thoại", Icons.phone_android, false, true, theme),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. NHÓM BẢO MẬT
                  _buildInfoCard(
                    theme: theme,
                    title: "Bảo mật",
                    children: [
                      _buildPasswordTextField(
                        controller: _passwordController,
                        hint: "Mật khẩu",
                        isConfirm: false,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordTextField(
                        controller: _confirmPasswordController,
                        hint: "Nhập lại mật khẩu",
                        isConfirm: true,
                        theme: theme,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 5. NHÓM MÃ GIỚI THIỆU
                  _buildInfoCard(
                    theme: theme,
                    title: "Mã giới thiệu (Tùy chọn)",
                    children: [
                      _buildTextField(
                        _referralCodeController,
                        "Nhập mã giới thiệu",
                        Icons.card_giftcard,
                        false,
                        false,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 6. ĐIỀU KHOẢN VÀ ĐĂNG KÝ
                  _buildTermsAndButton(theme),

                  const SizedBox(height: 25),

                  // 7. LIÊN KẾT QUAY LẠI LOGIN
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      "Bạn đã có tài khoản? Quay về đăng nhập",
                      style: TextStyle(
                        color: theme.colorScheme.secondary, // ✅ Màu vàng
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // LOADING OVERLAY
            if (_loading)
              Container(
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              )
          ],
        ),
      ),
    );
  }

// ================= WIDGET CON =================

  Widget _buildAvatarSection(ThemeData theme) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.grey.shade300, // ✅ Đổi sang màu xám sáng hơn
            backgroundImage:
            _avatar != null ? FileImage(File(_avatar!.path)) : null,
            child: _avatar == null
                ? Icon(
              Icons.person,
              size: 60, // ✅ Tăng size icon
              color: Colors.grey.shade600, // ✅ Icon xám đậm rõ ràng
            )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: InkWell(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.secondary, // Vàng
                child: const Icon(Icons.camera_alt,
                    size: 18, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary, // ✅ Tiêu đề màu vàng
              ),
            ),
            Divider(height: 20, color: theme.colorScheme.secondary.withOpacity(0.3)), // ✅ Divider vàng nhạt
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon,
      bool isPassword,
      bool isPhone,
      ThemeData theme,
      ) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary), // ✅ Icon xanh
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2), // ✅ Viền vàng khi focus
        ),
      ),
    );
  }

  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String hint,
    required bool isConfirm,
    required ThemeData theme,
  }) {
    final isObscure = isConfirm ? _obscureConfirmPassword : _obscurePassword;
    final toggleObscure = isConfirm
        ? () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
        : () => setState(() => _obscurePassword = !_obscurePassword);

    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary), // ✅ Icon xanh
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.secondary, // ✅ Icon vàng
          ),
          onPressed: toggleObscure,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2), // ✅ Viền vàng
        ),
      ),
    );
  }

  Widget _buildTermsAndButton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: _agreeTerms,
              activeColor: theme.colorScheme.secondary, // ✅ Checkbox vàng
              onChanged: (v) {
                setState(() => _agreeTerms = v!);
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  );
                },
                child: Text(
                  "Tôi đồng ý với Chính sách & Điều khoản sử dụng",
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: theme.colorScheme.secondary, // ✅ Text vàng
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary, // ✅ Nút vàng
              foregroundColor: Colors.black87, // ✅ Chữ đen
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Bo tròn như web
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              elevation: 3,
            ),
            onPressed: _loading ? null : _handleRegister,
            child: _loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black87, // ✅ Loading đen
              ),
            )
                : const Text("ĐĂNG KÝ"),
          ),
        ),
      ],
    );
  }
}