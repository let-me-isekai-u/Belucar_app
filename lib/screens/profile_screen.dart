import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/account_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/currency_format.dart';
import 'account_ui.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'update_profile_screen.dart';
import 'wallet_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _supportPhone = '0379550130';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _openZalo() async {
    final zaloUrl = Uri.parse('https://zalo.me/$_supportPhone');
    if (await canLaunchUrl(zaloUrl)) {
      await launchUrl(zaloUrl, mode: LaunchMode.externalApplication);
    } else {
      _showError('Không thể mở Zalo');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final result = await context.read<AccountProvider>().loadProfile();
      if (!mounted) return;
      final profile = result.data;
      if (result.isSuccess && profile != null) {
        setState(() {
          _nameController.text = profile.fullName;
          _emailController.text = profile.email;
          _phoneController.text = profile.phone;
          _wallet = profile.wallet;
          _avatarUrl = profile.avatarUrl;
          _referralCode = profile.referralCode;
          _loading = false;
        });
      } else {
        _showError(
          result.message ?? 'Không thể tải thông tin. Vui lòng đăng nhập lại.',
        );
        _goToLogin();
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Lỗi kết nối máy chủ.');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSupportDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Icon(
                Icons.headset_mic_rounded,
                size: 50,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Hỗ trợ khách hàng BeluCar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chúng tôi sẵn sàng hỗ trợ bạn 24/7.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSupportAction(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.10),
                    child: const Icon(Icons.phone, color: Colors.green),
                  ),
                  title: 'Gọi điện hỗ trợ',
                  subtitle: _supportPhone,
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse('tel:$_supportPhone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSupportAction(
                  leading: Image.asset(
                    'lib/assets/icons/icons8-zalo-100.png',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Nhắn tin Zalo',
                  subtitle: _supportPhone,
                  onTap: () {
                    Navigator.pop(context);
                    _openZalo();
                  },
                ),
              ),
              const SizedBox(height: 24),
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
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Tài khoản cá nhân',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Xoá tài khoản',
            onPressed: () => _showDeleteConfirmation(context, theme),
            icon: const Icon(Icons.close_rounded, color: Colors.red, size: 30),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: theme.colorScheme.secondary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(theme),
                    const SizedBox(height: 16),
                    _buildWalletCard(context, theme),
                    const SizedBox(height: 18),
                    AccountSectionCard(
                      title: 'Tiện ích tài khoản',
                      subtitle:
                          'Các thao tác chính liên quan đến hồ sơ và hỗ trợ.',
                      icon: Icons.manage_accounts_outlined,
                      child: Column(
                        children: [
                          _buildProfileListItem(
                            icon: Icons.edit_outlined,
                            title: 'Cập nhật thông tin cá nhân',
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
                              ).then((_) => _loadProfile());
                            },
                          ),
                          _buildProfileListItem(
                            icon: Icons.lock_outline_rounded,
                            title: 'Đổi mật khẩu',
                            iconColor: theme.colorScheme.secondary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChangePasswordScreen(),
                                ),
                              );
                            },
                          ),
                          _buildProfileListItem(
                            icon: Icons.headset_mic_outlined,
                            title: 'Liên hệ hỗ trợ',
                            iconColor: theme.colorScheme.secondary,
                            onTap: () => _showSupportDialog(context),
                          ),
                          _buildProfileListItem(
                            icon: Icons.attach_money_outlined,
                            title: 'Lịch sử tài chính',
                            iconColor: theme.colorScheme.secondary,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WalletHistoryScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AccountSectionCard(
                      title: 'Thông tin bổ sung',
                      subtitle: 'Email và mã giới thiệu gắn với tài khoản.',
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        children: [
                          _buildProfileListItem(
                            icon: Icons.email_outlined,
                            title: 'Email',
                            subtitle: _emailController.text,
                            iconColor: theme.colorScheme.secondary,
                            showArrow: false,
                            onTap: () {},
                          ),
                          if (_referralCode != null &&
                              _referralCode!.isNotEmpty)
                            _buildProfileListItem(
                              icon: Icons.card_giftcard_outlined,
                              title: 'Mã giới thiệu',
                              subtitle: _referralCode!,
                              iconColor: theme.colorScheme.secondary,
                              showArrow: false,
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: _referralCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã copy mã giới thiệu'),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AccountSectionCard(
                      title: 'Bảo mật và phiên đăng nhập',
                      subtitle: 'Các hành động nhạy cảm được tách riêng.',
                      icon: Icons.warning_amber_rounded,
                      child: _buildDangerousActions(context, theme),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWalletCard(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary.withValues(alpha: 0.94),
            const Color(0xFFFFD166),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.black87,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Số dư ví',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatWalletAmount(_wallet),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: theme.colorScheme.secondary.withValues(
              alpha: 0.15,
            ),
            backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ? NetworkImage(_avatarUrl!) as ImageProvider<Object>?
                : null,
            child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                ? Icon(
                    Icons.person_outline_rounded,
                    size: 60,
                    color: theme.colorScheme.secondary,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Người dùng BeluCar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _phoneController.text.isNotEmpty
                ? _phoneController.text
                : 'Chưa cập nhật số điện thoại',
            style: const TextStyle(fontSize: 16, color: Colors.white),
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
          label: const Text('Đăng xuất'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade300,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (!mounted) return;
            _goToLogin();
          },
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(icon, color: iconColor ?? Colors.white70),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Colors.white70))
          : null,
      trailing: showArrow
          ? const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  void _showDeleteConfirmation(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Xoá tài khoản',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
        content: const Text(
          'Bạn có chắc muốn xoá tài khoản không? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Huỷ',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(this.context);
              final result = await this.context
                  .read<AccountProvider>()
                  .deleteAccount();
              if (!mounted) return;
              if (result.isSuccess) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Tài khoản đã bị xoá')),
                );
                _goToLogin();
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result.message ?? 'Không thể xoá tài khoản'),
                  ),
                );
              }
            },
            child: const Text(
              'Xoá',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
