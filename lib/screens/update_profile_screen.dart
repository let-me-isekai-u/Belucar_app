import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'account_ui.dart';
import '../ui/ui.dart';

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.name;
    emailController.text = widget.email;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _avatar = picked);
      }
    } catch (_) {
      _showSnack('Không thể chọn ảnh');
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      if (mounted) {
        _showSnack('Phiên đăng nhập hết hạn.');
        Navigator.pop(context);
      }
      return;
    }

    final res = await ApiService.updateProfile(
      accessToken: accessToken,
      fullName: nameController.text.trim(),
      email: emailController.text.trim(),
      avatarFilePath: _avatar?.path,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.statusCode == 200) {
      _showSnack('Cập nhật thành công!');
      Navigator.pop(context, true);
    } else {
      try {
        final data = jsonDecode(res.body);
        _showSnack(data['message'] ?? 'Lỗi cập nhật.');
      } catch (_) {
        _showSnack('Cập nhật thất bại.');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Cập nhật thông tin',
          style: TextStyle(color: Brand.navy),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Brand.navy),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hồ sơ cá nhân',
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
            ),
            const SizedBox(height: 8),
            Text(
              'Tên, email và ảnh đại diện.',
              style: TextStyle(
                color: Brand.inkMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            AccountSectionCard(
              title: 'Ảnh đại diện',
              icon: Icons.photo_camera_back_outlined,
              child: Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Brand.navy,
                            width: 2,
                          ),
                          image: _avatar != null
                              ? DecorationImage(
                                  image: FileImage(File(_avatar!.path)),
                                  fit: BoxFit.cover,
                                )
                              : widget.avatarUrl != null &&
                                    widget.avatarUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(widget.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Brand.b50,
                        ),
                        child:
                            (_avatar == null &&
                                (widget.avatarUrl == null ||
                                    widget.avatarUrl!.isEmpty))
                            ? Icon(
                                Icons.person_outline_rounded,
                                size: 48,
                                color: Brand.navy,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Brand.navy,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AccountSectionCard(
              title: 'Thông tin cơ bản',
              icon: Icons.badge_outlined,
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Brand.ink),
                    decoration: accountInputDecoration(
                      context,
                      label: 'Họ và tên',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Brand.ink),
                    decoration: accountInputDecoration(
                      context,
                      label: 'Email',
                      icon: Icons.email_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('HUỶ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('LƯU THAY ĐỔI'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
