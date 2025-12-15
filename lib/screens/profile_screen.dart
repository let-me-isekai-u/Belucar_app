import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'update_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // 🔥 THÊM BIẾN LƯU URL AVATAR
  String? _avatarUrl;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    print("🔍 [PROFILE] Bắt đầu load profile...");

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString("accessToken");

      print("🔍 [PROFILE] accessToken: $accessToken");

      if (accessToken == null) {
        print("❌ [PROFILE] Không có token → login");
        _goToLogin();
        return;
      }

      final res = await ApiService.getCustomerProfile(accessToken: accessToken);

      print("📥 [PROFILE] Status: ${res.statusCode}");
      print("📥 [PROFILE] Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _nameController.text = data["fullName"] ?? "";
          _emailController.text = data["email"] ?? "";
          _phoneController.text = data["phone"] ?? "";

          // 🔥 LƯU URL AVATAR VÀO BIẾN TRẠNG THÁI
          _avatarUrl = data["avatarUrl"];

          _loading = false;
        });

        print("✅ [PROFILE] Load thành công.");
      } else {
        print("❌ [PROFILE] Token lỗi → logout");
        _showError("Không thể tải thông tin. Vui lòng đăng nhập lại.");
        _goToLogin();
      }
    } catch (e) {
      print("❌ [PROFILE] Exception: $e");
      _showError("Lỗi kết nối máy chủ.");
      _goToLogin();
    }
  }

  // [Các hàm khác giữ nguyên]
  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
  // [Hết các hàm khác]

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ---------- AVATAR ĐÃ SỬA ----------
            CircleAvatar(
              radius: 55,
              // Nền màu nhẹ nhàng
              backgroundColor: primaryColor.withOpacity(0.1),

              // 🔥 Dùng NetworkImage nếu có URL
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!) as ImageProvider<Object>?
                  : null,

              // Hiển thị Icon mặc định nếu không có URL ảnh
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 60, color: Colors.black54)
                  : null,
            ),

            // ... [Các phần còn lại giữ nguyên]
            const SizedBox(height: 25),

            // ---------- HỌ TÊN ----------
            TextField(
              controller: _nameController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: "Họ và tên",
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- EMAIL ----------
            TextField(
              controller: _emailController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ---------- SỐ ĐIỆN THOẠI ----------
            TextField(
              controller: _phoneController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: "Số điện thoại",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // ---------- BUTTONS ----------
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ----- Đổi mật khẩu -----
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                    );
                  },
                  child: const Text("Đổi mật khẩu"),
                ),


                const SizedBox(height: 12),

                // ----- Cập nhật thông tin -----
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UpdateProfileScreen(
                          name: _nameController.text,
                          email: _emailController.text,
                          // 🔥 TRUYỀN URL AVATAR QUA MÀN HÌNH CẬP NHẬT
                          avatarUrl: _avatarUrl,
                        ),
                      ),
                    );
                  },
                  child: const Text("Cập nhật thông tin"),
                ),
                const SizedBox(height: 12),


                // Xoá tài khoản
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Xoá tài khoản"),
                        content: const Text("Bạn có chắc muốn xoá tài khoản không? Hành động này không thể hoàn tác."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Huỷ"),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context); // đóng popup

                              final prefs = await SharedPreferences.getInstance();
                              final accessToken = prefs.getString("accessToken");

                              if (accessToken == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Phiên đăng nhập hết hạn")),
                                );
                                return;
                              }

                              // 🔥 Gọi API xoá tài khoản
                              // ... (Logic gọi API deleteAccount giữ nguyên)
                              final res = await ApiService.deleteAccount(accessToken: accessToken);

                              if (!mounted) return;

                              if (res.statusCode == 200) {
                                // Xoá token khỏi máy
                                await prefs.remove("accessToken");
                                await prefs.remove("refreshToken");

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Tài khoản đã bị xoá")),
                                );

                                // Chuyển về login
                                Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Không thể xoá tài khoản (${res.statusCode})")),
                                );
                              }
                            },
                            child: const Text("Xoá", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("Xoá tài khoản"),
                ),

                const SizedBox(height: 12),

                // ----- Đăng xuất -----
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final accessToken = prefs.getString("accessToken");

                    // Không có token → login luôn
                    if (accessToken == null) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                      );
                      return;
                    }

                    final res = await ApiService.logout(accessToken); // Giả định hàm logout này tồn tại

                    await prefs.clear();

                    if (!mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                    );
                  },
                  child: const Text("Đăng xuất"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}