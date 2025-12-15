import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Bổ sung import
import 'screens/beluca_home_screen.dart';
import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'Screens/splash_screen.dart';


void main() async { // THÊM TỪ KHÓA ASYNC

  // 1. Đảm bảo Flutter Widgets đã được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Khởi tạo Shared Preferences để đảm bảo có thể đọc token ngay lập tức
  // Đây là bước quan trọng để fix lỗi tiềm ẩn khi đọc token trên Splash Screen
  await SharedPreferences.getInstance();

  runApp(const BelucarApp());
}

class BelucarApp extends StatelessWidget {
  const BelucarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/splash", // Luôn bắt đầu từ Splash Screen

      routes: {
        "/splash": (_) => const SplashScreen(),
        "/login": (_) => const LoginScreen(),
        "/home": (_) => const HomeScreen(),
      },
      // title: 'BeluCar',
      theme: AppTheme.theme,
      // home: const SplashScreen(), // Đã chuyển sang initialRoute
    );
  }
}