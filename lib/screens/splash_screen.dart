import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minDisplayDuration = Duration(seconds: 3);
  late final DateTime _splashStart;

  @override
  void initState() {
    super.initState();
    _splashStart = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
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
        // Đánh dấu để Home hiển thị banner 1 lần khi vừa vào
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
          // Sau khi refresh token thành công, vẫn muốn show banner một lần
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
      body: SizedBox.expand(
        child: Image.asset(
          'lib/assets/tet_splash.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}