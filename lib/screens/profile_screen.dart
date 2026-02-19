import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import 'update_profile_screen.dart';
import 'wallet_history_screen.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _referralCode;

  String? _avatarUrl;

  bool _loading = true;

  double _wallet = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _openZalo() async {
    final Uri zaloUrl = Uri.parse('https://zalo.me/0379550130');
    if (await canLaunchUrl(zaloUrl)) {
      await launchUrl(zaloUrl, mode: LaunchMode.externalApplication);
    } else {
      _showError("Không thể mở Zalo");
    }
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

          _wallet = (data["wallet"] ?? 0.0).toDouble();

          _avatarUrl = data["avatarUrl"];
          _referralCode = data["referralCode"];

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

  void _showSupportDialog(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Icon(Icons.headset_mic_rounded,
                  size: 50, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),

              Text(
                "Hỗ trợ khách hàng BeluCar",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary, // ✅ Vàng gold
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                "Chúng tôi sẵn sàng hỗ trợ bạn 24/7.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              _buildSupportAction(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: const Icon(Icons.phone, color: Colors.green),
                ),
                title: "Gọi điện hỗ trợ",
                subtitle: "08 2341 6820",
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse('tel:0823416820');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),

              const SizedBox(height: 12),

              _buildSupportAction(
                leading: Image.asset(
                  'lib/assets/icons/icons8-zalo-100.png',
                  width: 40,
                  height: 40,
                ),
                title: "Nhắn tin Zalo",
                subtitle: "Phản hồi nhanh chóng",
                onTap: () {
                  Navigator.pop(context);
                  _openZalo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportAction({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87, // ✅ Đen cho dialog (nền trắng)
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Tài khoản Cá nhân",
          style: TextStyle(
            color: theme.colorScheme.secondary, // ✅ Màu vàng gold
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(theme),

            const SizedBox(height: 16),
            _buildWalletCard(context, theme),

            const SizedBox(height: 24),

            _buildActionButtons(context, theme),

            const SizedBox(height: 24),

            _buildDetailsCard(context, theme),

            const SizedBox(height: 30),

            _buildDangerousActions(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, ThemeData theme) {
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
                color: theme.colorScheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance_wallet,
                  color: theme.colorScheme.secondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Số dư ví",
                    style: TextStyle(
                      color: theme.colorScheme.secondary, // ✅ Vàng gold
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_wallet.toStringAsFixed(0)} đ",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // ✅ Trắng
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

  Widget _buildProfileHeader(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
              backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                  ? NetworkImage(_avatarUrl!) as ImageProvider<Object>?
                  : null,
              child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                  ? Icon(Icons.person, size: 70, color: theme.colorScheme.secondary)
                  : null,
            ),
            const SizedBox(height: 16),

            Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text
                  : "Người dùng BeluCar",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary, // ✅ Vàng gold
              ),
            ),
            const SizedBox(height: 4),

            Text(
              _phoneController.text.isNotEmpty
                  ? _phoneController.text
                  : "Chưa cập nhật SĐT",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white, // ✅ Trắng
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        _buildProfileListItem(
          icon: Icons.edit,
          title: "Cập nhật Thông tin cá nhân",
          iconColor: theme.colorScheme.secondary,
          onTap: () {
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
              _loadProfile();
            });
          },
        ),
        _buildProfileListItem(
          icon: Icons.lock,
          title: "Đổi Mật khẩu",
          iconColor: theme.colorScheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          },
        ),

        _buildProfileListItem(
          icon: Icons.headset_mic_rounded,
          title: "Liên hệ hỗ trợ",
          iconColor: theme.colorScheme.secondary,
          onTap: () => _showSupportDialog(context),
        ),

        _buildProfileListItem(
          icon: Icons.attach_money,
          title: "Lịch sử tài chính",
          iconColor: theme.colorScheme.secondary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletHistoryScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildProfileListItem(
            icon: Icons.email,
            title: "Email",
            subtitle: _emailController.text,
            iconColor: theme.colorScheme.secondary,
            showArrow: false,
            onTap: () {},
          ),
          if (_referralCode != null && _referralCode!.isNotEmpty)
            _buildProfileListItem(
              icon: Icons.card_giftcard,
              title: "Mã giới thiệu",
              subtitle: _referralCode!,
              iconColor: theme.colorScheme.secondary,
              showArrow: false,
              onTap: () {
                Clipboard.setData(ClipboardData(text: _referralCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Đã copy mã giới thiệu")),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDangerousActions(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade700,
          ),
          onPressed: () => _showDeleteConfirmation(context, theme),
          child: const Text("Xoá tài khoản", style: TextStyle(decoration: TextDecoration.underline)),
        ),
      ],
    );
  }

  Widget _buildProfileListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool showArrow = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor ?? Colors.white70),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white, // ✅ Trắng
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: const TextStyle(color: Colors.white70), // ✅ Trắng nhạt
      )
          : null,
      trailing: showArrow
          ? const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          "Xoá tài khoản",
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        content: const Text(
          "Bạn có chắc muốn xoá tài khoản không? Hành động này không thể hoàn tác.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Huỷ",
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final prefs = await SharedPreferences.getInstance();
              final accessToken = prefs.getString("accessToken");

              if (accessToken == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Phiên đăng nhập hết hạn")),
                );
                return;
              }

              final res = await ApiService.deleteAccount(accessToken: accessToken);

              if (!mounted) return;

              if (res.statusCode == 200) {
                await prefs.remove("accessToken");
                await prefs.remove("refreshToken");

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Tài khoản đã bị xoá")),
                );

                _goToLogin();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Không thể xoá tài khoản (${res.statusCode})")),
                );
              }
            },
            child: const Text(
              "Xoá",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}