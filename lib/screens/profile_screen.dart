import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../utils/currency_format.dart';
import 'account_ui.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'update_profile_screen.dart';
import 'wallet_history_screen.dart';
import '../ui/ui.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data / actions
  // ---------------------------------------------------------------------------

  Future<void> _openZalo() async {
    final zaloUrl = Uri.parse('https://zalo.me/0379550130');
    if (await canLaunchUrl(zaloUrl)) {
      await launchUrl(zaloUrl, mode: LaunchMode.externalApplication);
    } else {
      _showError('Không thể mở Zalo');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('accessToken');

      if (accessToken == null) {
        _goToLogin();
        return;
      }

      final res = await ApiService.getCustomerProfile(accessToken: accessToken);

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await prefs.setString('fullName', data['fullName']?.toString() ?? '');
        await prefs.setString('phone', data['phone']?.toString() ?? '');
        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _wallet = (data['wallet'] ?? 0.0).toDouble();
          _avatarUrl = data['avatarUrl'];
          _referralCode = data['referralCode'];
          _loading = false;
        });
      } else {
        _showError('Không thể tải thông tin. Vui lòng đăng nhập lại.');
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

  void _openUpdateProfile() {
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
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _openWalletHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletHistoryScreen()),
    );
  }

  void _onSettingSelected(_SettingsAction action) {
    switch (action) {
      case _SettingsAction.editProfile:
        _openUpdateProfile();
        break;
      case _SettingsAction.changePassword:
        _openChangePassword();
        break;
      case _SettingsAction.deleteAccount:
        _showDeleteConfirmation(context);
        break;
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');

    if (accessToken != null) {
      await ApiService.logout(accessToken);
    }

    await prefs.clear();
    if (!mounted) return;
    _goToLogin();
  }

  // ---------------------------------------------------------------------------
  // Support bottom sheet
  // ---------------------------------------------------------------------------

  void _showSupportDialog(BuildContext context) {
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
              Icon(
                Icons.headset_mic_rounded,
                size: 50,
                color: Brand.navy,
              ),
              const SizedBox(height: 16),
              Text(
                'Hỗ trợ khách hàng BeluCar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Brand.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chúng tôi sẵn sàng hỗ trợ bạn 24/7.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _buildSupportAction(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.10),
                  child: const Icon(Icons.phone, color: Colors.green),
                ),
                title: 'Gọi điện hỗ trợ',
                subtitle: '08 2341 6820',
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse('tel:0823416820');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                title: 'Nhắn tin Zalo',
                subtitle: 'Phản hồi nhanh chóng',
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
                      color: Brand.ink,
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasReferral = _referralCode != null && _referralCode!.isNotEmpty;

    return AccountScaffold(
      appBar: AppBar(
        title: Text(
          'Tài khoản cá nhân',
          style: TextStyle(color: Brand.navy),
        ),
        centerTitle: true,
        actions: _loading
            ? null
            : [
          _SettingsGearButton(onSelected: _onSettingSelected),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadProfile,
        color: Brand.navy,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FadeSlideIn(index: 0, child: _buildHeroCard()),
              const SizedBox(height: 18),
              _FadeSlideIn(
                index: 1,
                child: _buildInfoCard(hasReferral),
              ),
              const SizedBox(height: 18),
              _FadeSlideIn(index: 2, child: _buildLogoutButton()),
            ],
          ),
        ),
      ),
    );
  }

  /// Thẻ gộp: avatar + tên + SĐT ở trên, số dư ví ở dưới.
  Widget _buildHeroCard() {
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : 'Người dùng BeluCar';
    final phone = _phoneController.text.isNotEmpty
        ? _phoneController.text
        : 'Chưa cập nhật số điện thoại';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.navy, Brand.b700],
        ),
        boxShadow: [
          BoxShadow(
            color: Brand.navy.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Brand.b50,
                  backgroundImage: hasAvatar ? NetworkImage(_avatarUrl!) : null,
                  child: hasAvatar
                      ? null
                      : Icon(
                    Icons.person_outline_rounded,
                    size: 38,
                    color: Brand.navy,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 15,
                          color: Brand.b200,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Brand.b200,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 24,
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
                          color: Brand.b200,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatWalletAmount(_wallet),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Một thẻ duy nhất, không có tiêu đề mục.
  Widget _buildInfoCard(bool hasReferral) {
    final email = _emailController.text.trim();

    final tiles = <Widget>[
      // Email: chỉ xem, không tương tác.
      _InfoTile(
        icon: Icons.email_outlined,
        title: 'Email',
        subtitle: email.isNotEmpty ? email : 'Chưa cập nhật',
      ),
      if (hasReferral)
        _InfoTile(
          icon: Icons.card_giftcard_outlined,
          title: 'Mã giới thiệu',
          subtitle: _referralCode!,
          trailing: const Icon(
            Icons.copy_rounded,
            size: 18,
            color: Brand.inkMuted,
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            Clipboard.setData(ClipboardData(text: _referralCode!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã copy mã giới thiệu')),
            );
          },
        ),
      _InfoTile(
        icon: Icons.attach_money_outlined,
        title: 'Lịch sử tài chính',
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Brand.inkMuted,
        ),
        onTap: _openWalletHistory,
      ),
      _InfoTile(
        icon: Icons.headset_mic_outlined,
        title: 'Liên hệ hỗ trợ',
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Brand.inkMuted,
        ),
        onTap: () => _showSupportDialog(context),
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(
          const Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            endIndent: 16,
            color: Brand.line,
          ),
        );
      }
      children.add(tiles[i]);
    }

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Brand.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
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
      onPressed: _logout,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete account dialog
  // ---------------------------------------------------------------------------

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Xoá tài khoản',
          style: TextStyle(
            color: Colors.red.shade400,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Bạn có chắc muốn xoá tài khoản không? Hành động này không thể hoàn tác.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Huỷ',
              style: TextStyle(
                color: Brand.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(this.context);

              final prefs = await SharedPreferences.getInstance();
              final accessToken = prefs.getString('accessToken');

              if (accessToken == null) {
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Phiên đăng nhập hết hạn')),
                );
                return;
              }

              final res = await ApiService.deleteAccount(
                accessToken: accessToken,
              );

              if (!mounted) return;

              if (res.statusCode == 200) {
                await prefs.remove('accessToken');
                await prefs.remove('refreshToken');
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Tài khoản đã bị xoá')),
                );
                _goToLogin();
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Không thể xoá tài khoản (${res.statusCode})',
                    ),
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

// =============================================================================
// Info tile (dùng trong thẻ thông tin)
// =============================================================================

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// null => chỉ xem, không có ripple và không bấm được.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Brand.b50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Brand.navy, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Brand.ink,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle!,
        style: const TextStyle(color: Brand.inkMuted),
      )
          : null,
      trailing: trailing,
    );
  }
}

// =============================================================================
// Hiệu ứng xuất hiện cho các khối nội dung
// =============================================================================

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduce
          ? Duration.zero
          : Duration(milliseconds: 380 + index * 90),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

// =============================================================================
// Settings gear + animated dropdown menu
// =============================================================================

enum _SettingsAction { editProfile, changePassword, deleteAccount }

class _SettingsGearButton extends StatefulWidget {
  const _SettingsGearButton({required this.onSelected});

  final ValueChanged<_SettingsAction> onSelected;

  @override
  State<_SettingsGearButton> createState() => _SettingsGearButtonState();
}

class _SettingsGearButtonState extends State<_SettingsGearButton> {
  final GlobalKey _buttonKey = GlobalKey();
  bool _open = false;

  Future<void> _openMenu() async {
    // Chặn bấm nhiều lần khi menu đang mở/đóng.
    if (_open) return;

    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    HapticFeedback.selectionClick();

    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final reduce = MediaQuery.of(context).disableAnimations;

    setState(() => _open = true);

    final result = await showGeneralDialog<_SettingsAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng menu cài đặt',
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration:
      reduce ? Duration.zero : const Duration(milliseconds: 300),
      pageBuilder: (_, animation, __) =>
          _SettingsMenuPage(anchor: anchor, animation: animation),
      transitionBuilder: (_, __, ___, child) => child,
    );

    if (!mounted) return;
    setState(() => _open = false); // bánh răng xoay ngược lại

    if (result != null) {
      // Chờ menu đóng gần xong rồi mới thực hiện hành động.
      if (!reduce) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
      }
      widget.onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;

    return IconButton(
      key: _buttonKey,
      tooltip: 'Cài đặt',
      onPressed: _openMenu,
      icon: AnimatedRotation(
        turns: _open ? 0.25 : 0,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Icon(Icons.settings_rounded, color: Brand.navy),
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final _SettingsAction action;
  final bool destructive;
}

class _SettingsMenuPage extends StatefulWidget {
  const _SettingsMenuPage({required this.anchor, required this.animation});

  final Rect anchor;
  final Animation<double> animation;

  @override
  State<_SettingsMenuPage> createState() => _SettingsMenuPageState();
}

class _SettingsMenuPageState extends State<_SettingsMenuPage> {
  static const _entries = <_MenuEntry>[
    _MenuEntry(
      icon: Icons.edit_outlined,
      label: 'Cập nhật thông tin cá nhân',
      action: _SettingsAction.editProfile,
    ),
    _MenuEntry(
      icon: Icons.lock_outline_rounded,
      label: 'Đổi mật khẩu',
      action: _SettingsAction.changePassword,
    ),
    _MenuEntry(
      icon: Icons.delete_outline_rounded,
      label: 'Xoá tài khoản',
      action: _SettingsAction.deleteAccount,
      destructive: true,
    ),
  ];

  // Mở: easeOutCubic, đóng: easeInCubic (cảm giác đóng nhanh gọn hơn).
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool _closing = false;

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  void _select(_MenuEntry entry) {
    if (_closing) return;
    _closing = true;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(entry.action);
  }

  /// Fade + trượt nhẹ từ phải sang, lệch thời gian theo [index].
  Widget _staggered(int index, Widget child) {
    final start = 0.12 + index * 0.12;
    final progress = widget.animation.drive(
      CurveTween(
        curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
      ),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: progress.drive(
          Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  Widget _buildItem(int index, _MenuEntry entry) {
    final color = entry.destructive ? Colors.red.shade400 : Brand.navy;
    final textColor = entry.destructive ? Colors.red.shade400 : Brand.ink;

    return _staggered(
      index,
      InkWell(
        onTap: () => _select(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(entry.icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rightGap = media.size.width - widget.anchor.right;
    final right = rightGap < 12 ? 12.0 : rightGap;

    final rows = <Widget>[];
    for (var i = 0; i < _entries.length; i++) {
      // Đường kẻ tách riêng hành động nguy hiểm.
      if (_entries[i].destructive) {
        rows.add(
          _staggered(
            i,
            const Divider(
              height: 9,
              thickness: 1,
              indent: 14,
              endIndent: 14,
              color: Brand.line,
            ),
          ),
        );
      }
      rows.add(_buildItem(i, _entries[i]));
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: widget.anchor.bottom + 4,
            right: right,
            width: 280,
            child: FadeTransition(
              opacity: _curved,
              child: SlideTransition(
                position: _curved.drive(
                  Tween<Offset>(
                    begin: const Offset(0, -0.08),
                    end: Offset.zero,
                  ),
                ),
                child: ScaleTransition(
                  scale: _curved.drive(Tween<double>(begin: 0.9, end: 1.0)),
                  alignment: Alignment.topRight,
                  child: RepaintBoundary(
                    child: Material(
                      color: Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Brand.line),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rows,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}