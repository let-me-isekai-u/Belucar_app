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
      avatarFilePath: _avatar?.path ?? "", // app khách hàng có thể không cần để avatar
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


  // Trong _RegisterScreenState
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Đăng ký Tài khoản"), // Tiêu đề thân thiện hơn
        centerTitle: true,
        elevation: 0, // Bỏ bóng AppBar
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // 1. ẢNH AVATAR (GIỮ NGUYÊN)
                  _buildAvatarSection(primary),
                  const SizedBox(height: 24),

                  // 2. NHÓM THÔNG TIN CÁ NHÂN (Họ tên, Email)
                  _buildInfoCard(
                    title: "Thông tin cá nhân",
                    children: [
                      _buildTextField(_fullNameController, "Họ và tên", Icons.badge, false, false),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, "Email", Icons.email, false, false),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. NHÓM THÔNG TIN LIÊN HỆ (SĐT)
                  _buildInfoCard(
                    title: "Thông tin liên hệ",
                    children: [
                      _buildTextField(_phoneController, "Số điện thoại", Icons.phone, false, true),
                      const SizedBox(height: 16),
                      _buildTextField(_confirmPhoneController, "Nhập lại số điện thoại", Icons.phone_android, false, true),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. NHÓM BẢO MẬT (Mật khẩu)
                  _buildInfoCard(
                    title: "Bảo mật",
                    children: [
                      // MẬT KHẨU CÓ TOGGLE
                      _buildPasswordTextField(
                        controller: _passwordController,
                        hint: "Mật khẩu",
                        isConfirm: false,
                      ),
                      const SizedBox(height: 16),
                      // NHẬP LẠI MẬT KHẨU CÓ TOGGLE
                      _buildPasswordTextField(
                        controller: _confirmPasswordController,
                        hint: "Nhập lại mật khẩu",
                        isConfirm: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 5. ĐIỀU KHOẢN VÀ ĐĂNG KÝ
                  _buildTermsAndButton(primary),

                  const SizedBox(height: 25),

                  // 6. LIÊN KẾT QUAY LẠI LOGIN
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
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // Đảm bảo padding dưới cùng
                ],
              ),
            ),

            // LOADING OVERLAY (GIỮ NGUYÊN)
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

// ================= WIDGET CON MỚI =================

// Widget con cho phần Avatar
  Widget _buildAvatarSection(Color primary) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: primary.withOpacity(.15),
            backgroundImage:
            _avatar != null ? FileImage(File(_avatar!.path)) : null,
            child: _avatar == null
                ? const Icon(Icons.person, size: 55, color: Colors.black54)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: InkWell(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: primary,
                child: const Icon(Icons.camera_alt,
                    size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Widget con cho việc phân nhóm các TextField
  Widget _buildInfoCard({required String title, required List<Widget> children}) {
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
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 20),
            ...children, // Thêm các TextField
          ],
        ),
      ),
    );
  }

// Widget con TextField đã tối ưu
  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon,
      bool isPassword,
      bool isPhone,
      ) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        // Dùng kiểu Filled và bo góc nhẹ
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }

// Widget con cho Mật khẩu (có Toggle)
  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String hint,
    required bool isConfirm,
  }) {
    final theme = Theme.of(context);
    final isObscure = isConfirm ? _obscureConfirmPassword : _obscurePassword;
    final toggleObscure = isConfirm
        ? () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
        : () => setState(() => _obscurePassword = !_obscurePassword);

    return TextField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(Icons.lock, color: theme.colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            isObscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.secondary,
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }

// Widget con cho Điều khoản và Nút Đăng ký
  Widget _buildTermsAndButton(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              value: _agreeTerms,
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
                    color: primary,
                  ),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50, // Chiều cao cố định cho nút lớn
          child: FilledButton(
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            onPressed: _loading ? null : _handleRegister,
            child: _loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text("Đăng ký"),
          ),
        ),
      ],
    );
  }
}
