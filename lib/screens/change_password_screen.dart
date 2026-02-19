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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Đổi mật khẩu",
          style: TextStyle(
            color: theme.colorScheme.secondary, // ✅ Vàng gold
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary), // ✅ Icon back vàng
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(
                  Icons.lock_reset,
                  size: 85,
                  color: theme.colorScheme.secondary, // ✅ Icon vàng gold
                ),
              ),
              const SizedBox(height: 30),

              _buildField(
                controller: oldPassController,
                hint: "Mật khẩu cũ",
                obscureText: obscureOld,
                onToggle: () => setState(() => obscureOld = !obscureOld),
                theme: theme,
              ),

              const SizedBox(height: 20),

              _buildField(
                controller: newPassController,
                hint: "Mật khẩu mới",
                obscureText: obscureNew,
                onToggle: () => setState(() => obscureNew = !obscureNew),
                theme: theme,
              ),

              const SizedBox(height: 20),

              _buildField(
                controller: confirmController,
                hint: "Xác nhận mật khẩu",
                obscureText: obscureConfirm,
                onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
                theme: theme,
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary, // ✅ Nền vàng gold
                  foregroundColor: Colors.black87, // ✅ Chữ đen
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Đổi mật khẩu",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: theme.colorScheme.secondary, width: 2), // ✅ Border vàng
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Huỷ",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary, // ✅ Chữ vàng
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final oldPass = oldPassController.text.trim();
    final newPass = newPassController.text.trim();
    final confirm = confirmController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      return _toast("Vui lòng nhập đầy đủ thông tin");
    }

    if (oldPass == newPass) {
      return _toast("Mật khẩu mới không được trùng mật khẩu cũ");
    }

    final strongPassRegex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');

    if (!strongPassRegex.hasMatch(newPass)) {
      return _toast(
        "Mật khẩu quá yếu (cần chữ hoa, chữ thường, số và ký tự đặc biệt, tối thiểu 8 ký tự)",
      );
    }

    if (newPass != confirm) {
      return _toast("Mật khẩu xác nhận không khớp");
    }

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
    required ThemeData theme,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white), // ✅ Chữ trắng
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.transparent, // ✅ Trong suốt
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54), // ✅ Hint trắng nhạt
        prefixIcon: Icon(Icons.key, color: theme.colorScheme.secondary), // ✅ Icon vàng
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70, // ✅ Icon trắng nhạt
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white54), // ✅ Border trắng nhạt
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2), // ✅ Border vàng khi focus
        ),
      ),
    );
  }
}