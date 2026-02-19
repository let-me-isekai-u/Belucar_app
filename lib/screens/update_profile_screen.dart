import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class UpdateProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String? avatarUrl;

  const UpdateProfileScreen({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  XFile? _avatar;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.name;
    emailController.text = widget.email;
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked != null) {
        setState(() => _avatar = picked);
      }
    } catch (e) {
      _showSnack("Không thể chọn ảnh");
    }
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken");

    if (accessToken == null) {
      _showSnack("Phiên đăng nhập hết hạn.");
      Navigator.pop(context);
      return;
    }

    print("🔵 --- UPDATE PROFILE ---");
    print("📌 Name: ${nameController.text.trim()}");
    print("📌 Email: ${emailController.text.trim()}");
    print("📌 Avatar file: ${_avatar?.path}");

    final res = await ApiService.updateProfile(
      accessToken: accessToken,
      fullName: nameController.text.trim(),
      email: emailController.text.trim(),
      avatarFilePath: _avatar?.path,
    );

    print("📥 API status: ${res.statusCode}");
    print("📥 API body: ${res.body}");

    if (!mounted) return;

    if (res.statusCode == 200) {
      _showSnack("Cập nhật thành công!");
      Navigator.pop(context, true);
    } else {
      try {
        final data = jsonDecode(res.body);
        _showSnack(data["message"] ?? "Lỗi cập nhật.");
      } catch (_) {
        _showSnack("Cập nhật thất bại.");
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Cập nhật thông tin",
          style: TextStyle(
            color: theme.colorScheme.secondary, // ✅ Vàng gold
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.secondary), // ✅ Icon back vàng
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ---------- AVATAR ----------
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: theme.colorScheme.secondary.withOpacity(0.15), // ✅ Vàng nhạt
                      backgroundImage: _avatar != null
                          ? FileImage(File(_avatar!.path))
                          : (widget.avatarUrl != null
                          ? NetworkImage(widget.avatarUrl!)
                          : null),
                      child: (_avatar == null && widget.avatarUrl == null)
                          ? Icon(Icons.person,
                          size: 55, color: theme.colorScheme.secondary) // ✅ Icon vàng
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.secondary, // ✅ Nền vàng
                          child: const Icon(Icons.camera_alt,
                              size: 18, color: Colors.black87), // ✅ Icon đen
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ---------- FULL NAME ----------
              _buildField(
                controller: nameController,
                hint: "Họ và tên",
                icon: Icons.person_outline,
                theme: theme,
              ),
              const SizedBox(height: 20),

              // ---------- EMAIL ----------
              _buildField(
                controller: emailController,
                hint: "Email",
                icon: Icons.email_outlined,
                theme: theme,
              ),

              const SizedBox(height: 40),

              // ---------- SAVE BUTTON ----------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary, // ✅ Nền vàng
                    foregroundColor: Colors.black87, // ✅ Chữ đen
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Lưu",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ---------- CANCEL ----------
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.secondary, // ✅ Chữ vàng
                    side: BorderSide(color: theme.colorScheme.secondary, width: 2), // ✅ Border vàng
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Huỷ",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- TEXT FIELD UI ----------
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeData theme,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white), // ✅ Chữ trắng
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.transparent, // ✅ Nền trong suốt
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54), // ✅ Hint trắng nhạt
        prefixIcon: Icon(icon, color: theme.colorScheme.secondary), // ✅ Icon vàng
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