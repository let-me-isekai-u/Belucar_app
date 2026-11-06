import 'dart:convert';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/firebase_notification_service.dart';
import '../screens/beluca_home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../ui/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Brand.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showSnack('Vui lòng nhập số điện thoại và mật khẩu');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final deviceToken = await FirebaseNotificationService.getDeviceToken();
      final res = await ApiService.customerLogin(
        phone: phone,
        password: password,
        deviceToken: deviceToken ?? '',
      );

      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);

          final accessToken = data['accessToken'] ?? '';
          final refreshToken = data['refreshToken'] ?? '';
          final fullName = data['fullName'] ?? '';
          final int userId = data['id'] ?? 0;

          if (accessToken.isEmpty) {
            _showSnack('Server không trả về accessToken');
            return;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', accessToken);
          await prefs.setString('refreshToken', refreshToken);
          await prefs.setString('fullName', fullName);
          await prefs.setString('phone', phone);
          await prefs.setInt('id', userId);
          await prefs.setBool('showEventBanner', true);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } catch (_) {
          _showSnack('Lỗi dữ liệu từ server');
        }
        return;
      }

      try {
        final err = jsonDecode(res.body);
        _showSnack(err['message'] ?? 'Sai số điện thoại hoặc mật khẩu');
      } catch (_) {
        _showSnack('Đăng nhập thất bại (Mã: ${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Không thể đăng nhập: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Brand.surface,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final heroHeight = (constraints.maxHeight * 0.40).clamp(260.0, 360.0);
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LoginHero(height: heroHeight),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                        child: _buildForm(),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, 20, 24, 12 + bottomInset),
                        child: _buildFooter(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Đăng nhập',
            style: TextStyle(color: Brand.ink, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dùng số điện thoại bạn đã đăng ký',
            style: TextStyle(color: Brand.inkMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            style: const TextStyle(color: Brand.ink, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              hintText: '0912 345 678',
              prefixIcon: Icon(Icons.phone_outlined, color: Brand.navy),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) {
              if (!_isLoading) _login();
            },
            style: const TextStyle(color: Brand.ink, fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Brand.navy),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Brand.inkSubtle,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _goToForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: Brand.b600,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                minimumSize: Size.zero,
              ),
              child: const Text('Quên mật khẩu?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 6),
          PrimaryCta(
            label: 'Đăng nhập',
            loading: _isLoading,
            onPressed: _login,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Chưa có tài khoản?', style: TextStyle(color: Brand.inkMuted, fontSize: 15)),
        TextButton(
          onPressed: _goToRegister,
          style: TextButton.styleFrom(
            foregroundColor: Brand.navy,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: const Text('Đăng ký', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
      ],
    );
  }
}

/// Khối thương hiệu phía trên: nền navy bo góc dưới, con đường với vạch làn vàng,
/// logo + tên thương hiệu ở giữa.
class _LoginHero extends StatelessWidget {
  final double height;

  const _LoginHero({required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Brand.navy),
            const CustomPaint(painter: _RoadPainter()),
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    alignment: Alignment.center,
                    child: const BrandMark(size: 40),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Đông Dương',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Xe ghép · Limousine · Xe khách',
                    style: TextStyle(color: Brand.b200, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Con đường cong mờ với vạch làn vàng nét đứt — họa tiết "làn đường" của website.
class _RoadPainter extends CustomPainter {
  const _RoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final road = Path()
      ..moveTo(-40, h * 1.02)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.62, h * 1.04, w + 40, h * 0.80);

    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    final lane = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Brand.lane.withValues(alpha: 0.85);
    for (final PathMetric metric in road.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 14), lane);
        d += 26;
      }
    }

    // Vệt đường thứ hai mảnh hơn ở góc trên phải — tạo chiều sâu.
    final road2 = Path()
      ..moveTo(w * 0.55, -20)
      ..quadraticBezierTo(w * 0.95, h * 0.25, w + 30, h * 0.10);
    canvas.drawPath(
      road2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = Colors.white.withValues(alpha: 0.04),
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) => false;
}
