import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'account_ui.dart';

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
  bool _isSubmitting = false;

  @override
  void dispose() {
    oldPassController.dispose();
    newPassController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Đổi mật khẩu',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 38,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Cập nhật lớp bảo mật',
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 8),
            Text(
              'Đổi mật khẩu trực tiếp trong tài khoản. Mật khẩu mới cần đủ mạnh và khác mật khẩu cũ.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            const AccountInfoBanner(
              text:
                  'Mật khẩu mạnh nên có chữ hoa, chữ thường, số và ký tự đặc biệt, tối thiểu 8 ký tự.',
            ),
            const SizedBox(height: 18),
            AccountSectionCard(
              title: 'Thông tin mật khẩu',
              subtitle: 'Nhập đầy đủ ba trường trước khi xác nhận thay đổi.',
              icon: Icons.lock_reset_rounded,
              child: Column(
                children: [
                  _buildField(
                    controller: oldPassController,
                    label: 'Mật khẩu cũ',
                    obscureText: obscureOld,
                    onToggle: () => setState(() => obscureOld = !obscureOld),
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: newPassController,
                    label: 'Mật khẩu mới',
                    obscureText: obscureNew,
                    onToggle: () => setState(() => obscureNew = !obscureNew),
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: confirmController,
                    label: 'Xác nhận mật khẩu',
                    obscureText: obscureConfirm,
                    onToggle: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('HUỶ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                          )
                        : const Text('ĐỔI MẬT KHẨU'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final oldPass = oldPassController.text.trim();
    final newPass = newPassController.text.trim();
    final confirm = confirmController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      return _toast('Vui lòng nhập đầy đủ thông tin');
    }

    if (oldPass == newPass) {
      return _toast('Mật khẩu mới không được trùng mật khẩu cũ');
    }

    final strongPassRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );

    if (!strongPassRegex.hasMatch(newPass)) {
      return _toast(
        'Mật khẩu quá yếu (cần chữ hoa, chữ thường, số và ký tự đặc biệt, tối thiểu 8 ký tự)',
      );
    }

    if (newPass != confirm) {
      return _toast('Mật khẩu xác nhận không khớp');
    }

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null) {
      if (mounted) {
        _toast('Phiên đăng nhập hết hạn!');
        setState(() => _isSubmitting = false);
      }
      return;
    }

    final res = await ApiService.changePassword(
      accessToken: token,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.statusCode == 200) {
      _toast('Đổi mật khẩu thành công!');
      Navigator.pop(context);
    } else {
      _toast('Đổi mật khẩu thất bại\n${res.body}');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: accountInputDecoration(
        context,
        label: label,
        icon: Icons.key_outlined,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }
}
