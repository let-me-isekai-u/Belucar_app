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

  // 🔥 THÊM BIẾN LƯU URL AVATAR (GIỮ NGUYÊN LOGIC CŨ)
  String? _avatarUrl;

  bool _loading = true;

  double _wallet = 0.0;
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= LOGIC API VÀ STATE (GIỮ NGUYÊN) =================
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

      // Logic gọi API giữ nguyên
      final res = await ApiService.getCustomerProfile(accessToken: accessToken);

      print("📥 [PROFILE] Status: ${res.statusCode}");
      print("📥 [PROFILE] Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          _nameController.text = data["fullName"] ?? "";
          _emailController.text = data["email"] ?? "";
          _phoneController.text = data["phone"] ?? "";

          _wallet = (data["wallet"] ?? 0.0).toDouble();

          // LƯU URL AVATAR VÀO BIẾN TRẠNG THÁI
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

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tài khoản Cá nhân"), // Tiêu đề thân thiện hơn
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. PHẦN TỔNG QUAN HỒ SƠ (AVATAR VÀ TÊN)
            _buildProfileHeader(primaryColor),

            const SizedBox(height: 16),
            _buildWalletCard(context),

            const SizedBox(height: 24),

            // 2. CÁC LỰA CHỌN THAO TÁC (MENU ACTIONS: Update, Change Password)
            _buildActionButtons(context),

            const SizedBox(height: 24),

            // 3. THÔNG TIN CHI TIẾT (Hiển thị Email)
            _buildDetailsCard(context),

            const SizedBox(height: 30),

            // 4. ĐĂNG XUẤT VÀ XÓA TÀI KHOẢN (Actions nguy hiểm)
            _buildDangerousActions(context),
          ],
        ),
      ),
    );
  }

  // ================= WIDGET CON CHO GIAO DIỆN MỚI =================

  Widget _buildWalletCard(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.green, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Số dư ví",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_wallet.toStringAsFixed(0)} đ",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Header (Avatar và Tên)
  Widget _buildProfileHeader(Color primaryColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            // AVATAR
            CircleAvatar(
              radius: 60,
              backgroundColor: primaryColor.withOpacity(0.15),
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!) as ImageProvider<Object>?
                  : null,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? Icon(Icons.person, size: 70, color: primaryColor)
                  : null,
            ),
            const SizedBox(height: 16),

            // HỌ TÊN NỔI BẬT (Lấy từ Controller đã load data)
            Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text
                  : "Người dùng BeluCar",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // SỐ ĐIỆN THOẠI (Lấy từ Controller đã load data)
            Text(
              _phoneController.text.isNotEmpty
                  ? _phoneController.text
                  : "Chưa cập nhật SĐT",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Các Lựa chọn Thao tác (Cập nhật, Đổi mật khẩu)
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildProfileListItem(
          icon: Icons.edit,
          title: "Cập nhật Thông tin cá nhân",
          onTap: () {
            // LOGIC CHUYỂN MÀN HÌNH CŨ ĐÃ ĐƯỢC ĐƯA VÀO ĐÂY
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UpdateProfileScreen(
                  name: _nameController.text,
                  email: _emailController.text,
                  avatarUrl: _avatarUrl,
                ),
              ),
            ).then((_) {
              // Reload profile sau khi update xong
              _loadProfile();
            });
          },
        ),
        _buildProfileListItem(
          icon: Icons.lock,
          title: "Đổi Mật khẩu",
          onTap: () {
            // LOGIC CHUYỂN MÀN HÌNH CŨ ĐÃ ĐƯỢC ĐƯA VÀO ĐÂY
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          },
        ),
      ],
    );
  }

  // 3. Thông tin chi tiết (Hiển thị Email)
  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildProfileListItem(
            icon: Icons.email,
            title: "Email",
            subtitle: _emailController.text,
            showArrow: false, // Không cần mũi tên
            onTap: () {}, // Không làm gì
          ),
        ],
      ),
    );
  }

  // 4. Đăng xuất và Xóa tài khoản
  Widget _buildDangerousActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ----- Đăng xuất (Sử dụng OutlinedButton) -----
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text("Đăng xuất"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade700),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            // LOGIC ĐĂNG XUẤT CŨ ĐÃ ĐƯỢC ĐƯA VÀO ĐÂY
            final prefs = await SharedPreferences.getInstance();
            final accessToken = prefs.getString("accessToken");

            if (accessToken == null) {
              _goToLogin();
              return;
            }

            final res = await ApiService.logout(accessToken);

            await prefs.clear();

            if (!mounted) return;

            _goToLogin();
          },
        ),
        const SizedBox(height: 12),

        // ----- Xoá tài khoản (Sử dụng TextButton) -----
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade700,
          ),
          onPressed: () => _showDeleteConfirmation(context), // Logic được tách ra hàm dưới
          child: const Text("Xoá tài khoản", style: TextStyle(decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  // ================= HELPERS VÀ LOGIC PHỤ =================

  // Widget ListItem dùng chung cho các Menu/Thông tin
  Widget _buildProfileListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: showArrow ? const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // Hàm xử lý xác nhận xóa tài khoản (Logic xóa tài khoản CŨ)
  void _showDeleteConfirmation(BuildContext context) {
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

              // Gọi API xoá tài khoản (LOGIC CŨ)
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
                _goToLogin();
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
  }
}