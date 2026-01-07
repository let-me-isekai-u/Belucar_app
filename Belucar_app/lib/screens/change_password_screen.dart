import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController oldPassController = TextEditingController();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đổi mật khẩu"),
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(Icons.lock_reset, size: 85, color: Colors.teal),
              ),
              const SizedBox(height: 30),

              _buildField(
                controller: oldPassController,
                hint: "Mật khẩu cũ",
                obscureText: obscureOld,
                onToggle: () => setState(() => obscureOld = !obscureOld),
              ),

              const SizedBox(height: 20),

              _buildField(
                controller: newPassController,
                hint: "Mật khẩu mới",
                obscureText: obscureNew,
                onToggle: () => setState(() => obscureNew = !obscureNew),
              ),

              const SizedBox(height: 20),

              _buildField(
                controller: confirmController,
                hint: "Xác nhận mật khẩu",
                obscureText: obscureConfirm,
                onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Đổi mật khẩu",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Huỷ", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Logic đổi mật khẩu =====
  Future<void> _handleChangePassword() async {
    final oldPass = oldPassController.text.trim();
    final newPass = newPassController.text.trim();
    final confirm = confirmController.text.trim();

    // Validate 1: Không được bỏ trống
    if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      return _toast("Vui lòng nhập đầy đủ thông tin");
    }

    // Validate 2: Mật khẩu mới không trùng mật khẩu cũ
    if (oldPass == newPass) {
      return _toast("Mật khẩu mới không được trùng mật khẩu cũ");
    }

    // Validate 3: Mật khẩu mạnh
    final strongPassRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

    if (!strongPassRegex.hasMatch(newPass)) {
      return _toast(
        "Mật khẩu quá yếu (cần chữ hoa, chữ thường, số và ký tự đặc biệt, tối thiểu 8 ký tự)",
      );
    }

    // Validate 4: Xác nhận mật khẩu
    if (newPass != confirm) {
      return _toast("Mật khẩu xác nhận không khớp");
    }

    // Lấy token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token == null) {
      _toast("Phiên đăng nhập hết hạn!");
      return;
    }

    final res = await ApiService.changePassword(
      accessToken: token,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    if (res.statusCode == 200) {
      _toast("Đổi mật khẩu thành công!");
      Navigator.pop(context);
    } else {
      _toast("Đổi mật khẩu thất bại\n${res.body}");
    }
  }


  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        hintText: hint,
        prefixIcon: const Icon(Icons.key),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
