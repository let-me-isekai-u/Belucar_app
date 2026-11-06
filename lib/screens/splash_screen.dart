import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/firebase_notification_service.dart';
import '../ui/ui.dart';

void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minDisplayDuration = Duration(milliseconds: 1500);
  late final DateTime _splashStart;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _splashStart = DateTime.now();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await FirebaseNotificationService.init();
      } catch (e, s) {
        debugPrint('NOTI INIT ERROR: $e');
        debugPrint('$s');
      }
      _checkAuth();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _ensureMinDisplay() async {
    final elapsed = DateTime.now().difference(_splashStart);
    if (elapsed < _minDisplayDuration) {
      await Future.delayed(_minDisplayDuration - elapsed);
    }
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    final refreshToken = prefs.getString('refreshToken');

    if (accessToken == null || accessToken.isEmpty) {
      _goLogin();
      return;
    }

    try {
      final res = await ApiService.getCustomerProfile(accessToken: accessToken);

      if (!mounted) return;

      if (res.statusCode == 200) {
        await prefs.setBool('showEventBanner', true);
        await _ensureMinDisplay();
        _goHome();
        return;
      }

      if (res.statusCode == 401) {
        await prefs.remove('accessToken');
      }
    } catch (_) {
      await prefs.remove('accessToken');
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      _clearAndLogin();
      return;
    }

    try {
      final res = await ApiService.refreshToken(refreshToken: refreshToken);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newAccess = data['accessToken'];
        final newRefresh = data['refreshToken'];

        if (newAccess != null && newRefresh != null) {
          await prefs.setString('accessToken', newAccess);
          await prefs.setString('refreshToken', newRefresh);
          await prefs.setBool('showEventBanner', true);
          await _ensureMinDisplay();
          _goHome();
          return;
        }
      }
    } catch (_) {}

    _clearAndLogin();
  }

  Future<void> _clearAndLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    _goLogin();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.navy,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Align(
              alignment: Alignment(0, 0.18),
              child: Opacity(
                opacity: 0.35,
                child: SizedBox(height: 3, child: DashedLine(axis: Axis.horizontal, color: Brand.lane, dash: 16, gap: 10, thickness: 3)),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
                    alignment: Alignment.center,
                    child: const BrandMark(size: 54),
                  ),
                  const SizedBox(height: 22),
                  const Text('ĐÔNG DƯƠNG',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 4)),
                  const SizedBox(height: 6),
                  const Text('Xe ghép · Limousine · Xe khách',
                      style: TextStyle(color: Brand.b200, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 72),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShimmerLoadingBar(animation: _shimmerAnimation),
                    const SizedBox(height: 10),
                    const Text('Đang tải...', style: TextStyle(color: Brand.b200, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.6)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLoadingBar extends StatelessWidget {
  final Animation<double> animation;

  const _ShimmerLoadingBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(color: Colors.white.withOpacity(0.25)),
                  FractionallySizedBox(
                    alignment: Alignment((animation.value * 3.0) - 1.5, 0),
                    widthFactor: 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
