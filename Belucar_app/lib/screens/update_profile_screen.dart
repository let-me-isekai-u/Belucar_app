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

  // PICK AVATAR
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

  // CALL API UPDATE
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
      Navigator.pop(context, true); // reload lại profile
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
    return Scaffold(
      appBar: AppBar(title: const Text("Cập nhật thông tin")),
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
                      backgroundColor: Colors.teal.shade100,
                      backgroundImage: _avatar != null
                          ? FileImage(File(_avatar!.path))
                          : (widget.avatarUrl != null
                          ? NetworkImage(widget.avatarUrl!)
                          : null),
                      child: (_avatar == null && widget.avatarUrl == null)
                          ? const Icon(Icons.person,
                          size: 55, color: Colors.black54)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.camera_alt,
                              size: 18, color: Colors.white),
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
              ),
              const SizedBox(height: 20),

              // ---------- EMAIL ----------
              _buildField(
                controller: emailController,
                hint: "Email",
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 40),

              // ---------- SAVE BUTTON ----------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Lưu", style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 12),

              // ---------- CANCEL ----------
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Huỷ", style: TextStyle(fontSize: 16)),
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
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[100],
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
