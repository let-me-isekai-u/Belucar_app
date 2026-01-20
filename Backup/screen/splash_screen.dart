import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    /// 🚨 QUAN TRỌNG: delay auth check sau frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    final refreshToken = prefs.getString('refreshToken');

    appLog('AUTH', 'AccessToken: ${accessToken != null}');
    appLog('AUTH', 'RefreshToken: ${refreshToken != null}');

    await Future.delayed(const Duration(milliseconds: 1200));

    /// 1️⃣ Không có access token
    if (accessToken == null || accessToken.isEmpty) {
      _goLogin();
      return;
    }

    /// 2️⃣ Verify bằng API PROFILE
    try {
      final res = await ApiService.getCustomerProfile(accessToken: accessToken);

      if (!mounted) return;

      if (res.statusCode == 200) {
        appLog('AUTH', 'Profile OK → Home');
        _goHome();
        return;
      }

      if (res.statusCode == 401) {
        appLog('AUTH', 'Access token expired');
        await prefs.remove('accessToken');
      }
    } catch (e) {
      appLog('AUTH', 'Profile error: $e');
      await prefs.remove('accessToken');
    }

    /// 3️⃣ Refresh token
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
          _goHome();
          return;
        }
      }
    } catch (e) {
      appLog('AUTH', 'Refresh error: $e');
    }

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
    final theme = Theme.of(context);
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              SizedBox(height: h * 0.18),

              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'lib/assets/icons/BeluCar_logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'BELUCAR',
                style: theme.textTheme.headlineLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),

              const Spacer(),

              const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),

              SizedBox(height: h * 0.12),
            ],
          ),
        ),
      ),
    );
  }
}
