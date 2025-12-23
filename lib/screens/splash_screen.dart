import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart'; //debugPrint

// Hàm ghi nhật ký (Log) đơn giản để dễ theo dõi trong Terminal
void appLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {

  // --- Animation Controllers ---
  late AnimationController _logoController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    appLog('SPLASH', 'initState called. Setting up animations.');

    // Khởi tạo Animation cho hiệu ứng Logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    // Bắt đầu kiểm tra xác thực ngay khi màn hình được tạo
    _checkAuth();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  // LOGIC KIỂM TRA XÁC THỰC
  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString("accessToken"); // Lấy cả Access Token
    final refreshToken = prefs.getString("refreshToken");

    appLog('AUTH', '--- Starting Token Check ---');
    appLog('AUTH', 'Access Token Exists: ${accessToken != null}');
    appLog('AUTH', 'Refresh Token Exists: ${refreshToken != null}');

    // Thêm delay 1.5 giây để người dùng kịp thấy Splash Screen
    await Future.delayed(const Duration(milliseconds: 1500));

    // BƯỚC 1: KIỂM TRA ACCESS TOKEN
    if (accessToken != null) {
      // Có Access Token -> Vào Home ngay (Flow nhanh)
      appLog('AUTH', 'Found Access Token -> Go to Home.');
      _goToHome();
      return;
    }

    // BƯỚC 2: KIỂM TRA REFRESH TOKEN
    if (refreshToken == null) {
      // Không có cả hai token -> Bắt đăng nhập
      appLog('AUTH', 'No tokens found -> Go to Login.');
      _goToLogin();
      return;
    }

    // BƯỚC 3: GỌI API REFRESH
    // Nếu không có Access Token nhưng có Refresh Token -> Thử làm mới
    appLog('AUTH', 'Access Token missing, attempting Refresh Token...');

    try {
      final res = await ApiService.refreshToken(refreshToken: refreshToken);
      appLog('AUTH', 'Refresh API Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final newAccessToken = data["accessToken"];
        final newRefreshToken = data["refreshToken"];

        if (newAccessToken != null && newRefreshToken != null) {
          await prefs.setString("accessToken", newAccessToken);
          await prefs.setString("refreshToken", newRefreshToken);
          appLog('AUTH', 'Refresh SUCCESS -> New tokens saved -> Go to Home.');
          _goToHome();
          return;
        } else {
          // 200 Ok nhưng token mới bị thiếu trong body
          appLog('AUTH', 'Refresh 200 but missing new tokens in body. Clearing tokens -> Go to Login.');
          _goToLoginAndClear(prefs);
          return;
        }
      } else {
        // Lỗi Refresh: 401, 403, 500
        String message = "Unknown Error";
        try {
          final errorBody = jsonDecode(res.body);
          message = errorBody["message"] ?? message;
        } catch (_) {}
        appLog('AUTH', 'Refresh FAILED (${res.statusCode}): $message. Clearing tokens -> Go to Login.');
        _goToLoginAndClear(prefs);
      }
    } catch (e) {
      // Lỗi kết nối mạng, timeout, hoặc lỗi parse JSON
      appLog('AUTH', 'Refresh ERROR (Network/Parsing): $e. Clearing tokens -> Go to Login.');
      _goToLoginAndClear(prefs);
    }
  }

  // Hàm dọn dẹp token và chuyển hướng
  Future<void> _goToLoginAndClear(SharedPreferences prefs) async {
    await prefs.remove("accessToken");
    await prefs.remove("refreshToken");
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/login");
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/home");
  }


  // Trong _SplashScreenState
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    // Xác định khoảng trống trên/dưới logo
    final verticalPadding = mediaQuery.size.height * 0.15;

    return Scaffold(
        backgroundColor: theme.colorScheme.primary,
        body: Center(
          // Bỏ SingleChildScrollView vì đây là màn hình cố định
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Spacer ở trên (tạo cân bằng thị giác)
                SizedBox(height: verticalPadding),

                // 1. Khu vực Logo với hiệu ứng Scale
                ScaleTransition(
                  scale: _scaleAnimation, // Sử dụng Animation đã khai báo
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20), // Bo góc lớn hơn
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4), // Bóng đậm hơn
                          blurRadius: 20,
                          spreadRadius: 3,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'lib/assets/icons/BeluCar_logo.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 2. Tên Ứng dụng
                Text(
                  "BELUCAR",
                  style: theme.textTheme.headlineLarge!.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 32, // Đảm bảo kích thước lớn và rõ ràng
                    color: Colors.white,
                    letterSpacing: 4, // Tăng khoảng cách chữ cho sự nổi bật
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.4),
                        offset: const Offset(3, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),



                // Spacer ở giữa (đẩy Indicator xuống dưới)
                const Spacer(),

                // 4. Indicator (Được đẩy xuống gần cuối màn hình hơn)
                SizedBox(
                  width: 40, // Kích thước nhỏ gọn hơn
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3, // Giảm độ dày
                  ),
                ),

                const SizedBox(height: 20),

                // Spacer ở dưới (tạo cân bằng thị giác)
                SizedBox(height: verticalPadding / 2),
              ],
            ),
          ),
        )
    );
    }

}