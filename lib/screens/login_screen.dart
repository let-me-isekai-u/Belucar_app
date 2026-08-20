import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking_model.dart';
import '../providers/account_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/concert_provider.dart';
import '../screens/beluca_home_screen.dart';
import '../services/concert_api_service.dart';
import '../services/firebase_notification_service.dart';
import '../services/guest_concert_order_storage.dart';
import '../services/login_credential_storage.dart';
import 'auth_ui.dart';
import 'concert/concert_booking_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _supportPhone = '0379550130';

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await LoginCredentialStorage.read();
      if (!mounted || credentials == null) return;
      if (phoneController.text.isEmpty) {
        phoneController.text = credentials.phone;
      }
      if (passwordController.text.isEmpty) {
        passwordController.text = credentials.password;
      }
    } catch (_) {
      // Secure storage không khả dụng thì người dùng vẫn có thể nhập thủ công.
    }
  }

  Future<void> _reloadSavedCredentials() async {
    try {
      final credentials = await LoginCredentialStorage.read();
      if (!mounted || credentials == null) return;
      phoneController.text = credentials.phone;
      passwordController.text = credentials.password;
      setState(() {});
    } catch (_) {
      // Secure storage không khả dụng thì người dùng vẫn có thể nhập thủ công.
    }
  }

  Future<void> _clearSavedCredentials() async {
    phoneController.clear();
    passwordController.clear();
    try {
      await LoginCredentialStorage.clear();
    } catch (_) {
      // Vẫn giữ form trống để người dùng nhập tài khoản khác.
    }
    if (!mounted) return;
    setState(() {});
    _showSnack(
      'Đã xoá thông tin đăng nhập đã lưu',
      color: Colors.green.shade700,
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _login() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      _showSnack('Vui lòng nhập đầy đủ thông tin');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final deviceToken = await FirebaseNotificationService.getDeviceToken();
      if (!mounted) return;
      final result = await context.read<AuthProvider>().login(
        phone: phone,
        password: password,
        deviceToken: deviceToken ?? '',
      );
      if (!mounted) return;
      if (!result.isSuccess) {
        _showSnack(result.message ?? 'Sai tài khoản hoặc mật khẩu');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showSnack('Không thể đăng nhập: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _goToForgotPassword() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _buyConcertTicketAsGuest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => BookingModel()),
            ChangeNotifierProvider(
              create: (_) => ConcertProvider(
                authProvider: context.read<AuthProvider>(),
                accountProvider: context.read<AccountProvider>(),
                apiService: context.read<ConcertApiService>(),
                guestStorage: context.read<GuestConcertOrderStorage>(),
                guestMode: true,
              )..loadCatalog(),
            ),
          ],
          child: const ConcertBookingScreen(isGuest: true),
        ),
      ),
    );
    await _reloadSavedCredentials();
  }

  Future<void> _openZaloSupport() async {
    final uri = Uri.parse('https://zalo.me/$_supportPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Không thể mở Zalo');
    }
  }

  Future<void> _callSupport() async {
    final uri = Uri.parse('tel:$_supportPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Không thể gọi CSKH');
    }
  }

  void _showSupportDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Icon(
              Icons.headset_mic_rounded,
              size: 48,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Chăm sóc khách hàng',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Chọn phương thức liên hệ để được hỗ trợ nhanh nhất.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF303030), height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSupportAction(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.10),
                  child: const Icon(Icons.phone, color: Colors.green),
                ),
                title: 'Gọi điện hỗ trợ',
                subtitle: _supportPhone,
                onTap: () {
                  Navigator.pop(dialogContext);
                  _callSupport();
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
                  Navigator.pop(dialogContext);
                  _openZaloSupport();
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
                      color: Color(0xFF202020),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF505050),
                      fontWeight: FontWeight.w700,
                    ),
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
    return AuthScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.04).animate(
                    CurvedAnimation(
                      parent: _logoController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: const AuthLogoHero(
                    title: 'Đăng nhập Đông Dương',
                    subtitle: '',
                    assetPath: 'lib/assets/icons/dong_duong_logo.png',
                    logoSize: 108,
                    centered: true,
                  ),
                ),
                const SizedBox(height: 22),
                AuthPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuthSectionLabel('Thông tin đăng nhập'),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: authInputDecoration(
                          context,
                          label: 'Số điện thoại',
                          hint: 'Nhập số điện thoại đã đăng ký',
                          icon: Icons.phone_outlined,
                          suffixIcon: IconButton(
                            tooltip: 'Xoá thông tin đăng nhập đã lưu',
                            onPressed: _clearSavedCredentials,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: authInputDecoration(
                          context,
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _buyConcertTicketAsGuest,
                              icon: const Icon(
                                Icons.music_note_rounded,
                                size: 19,
                              ),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('ĐI CONCERT NÀO!'),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.secondary,
                                side: BorderSide(
                                  color: theme.colorScheme.secondary,
                                ),
                                minimumSize: const Size(0, 56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('ĐĂNG NHẬP'),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _goToForgotPassword,
                      child: Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    TextButton(
                      onPressed: _goToRegister,
                      child: Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: _showSupportDialog,
                    icon: Icon(
                      Icons.headset_mic_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                    label: Text(
                      'Chăm sóc khách hàng',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
