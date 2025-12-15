import 'package:flutter/material.dart';
import '../screens/beluca_home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'dart:convert';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
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
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
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

  // ----------------------------------------------------------------------
  // 🔥 LOGIN API CALL
  // ----------------------------------------------------------------------
  Future<void> _login() async {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showSnack("Vui lòng nhập đầy đủ thông tin");
      return;
    }

    setState(() => _isLoading = true);

    // DeviceToken -> nếu bạn chưa có thì để tạm ""
    final deviceToken = "";

    final res = await ApiService.customerLogin(
      phone: phone,
      password: password,
      deviceToken: deviceToken,
    );

    setState(() => _isLoading = false);

    // ---------------------- XỬ LÝ RESPONSE ----------------------
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body);

        final accessToken = data["accessToken"] ?? "";
        final refreshToken = data["refreshToken"] ?? "";
        final fullName = data["fullName"] ?? "";

        print("🔥 LOGIN accessToken = $accessToken");
        print("🔥 LOGIN refreshToken = $refreshToken");
        print("🔥 LOGIN fullName = $fullName");

        if (accessToken.isEmpty) {
          _showSnack("Server không trả về accessToken");
          return;
        }

        // Lưu token + fullName
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("accessToken", accessToken);
        await prefs.setString("refreshToken", refreshToken);
        await prefs.setString("fullName", fullName);

        _showSnack(
          "Đăng nhập thành công!",
          color: Theme.of(context).colorScheme.secondary,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } catch (_) {
        _showSnack("Lỗi dữ liệu từ server");
      }

      print("📦 Server login raw: ${res.body}");
    } else {
      try {
        final err = jsonDecode(res.body);
        _showSnack(err["message"] ?? "Sai tài khoản hoặc mật khẩu");
      } catch (_) {
        _showSnack("Đăng nhập thất bại (Mã: ${res.statusCode})");
      }
    }
  }

  // ----------------------------------------------------------------------

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ---------- LOGO ----------
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                  CurvedAnimation(
                    parent: _logoController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'lib/assets/icons/BeluCar_logo.jpg',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                "BeluCar",
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: 'Serif',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ) ??
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 40),

              // ---------- INPUTS ----------
              _buildTextField(
                  phoneController, "Số điện thoại", Icons.phone, false),
              const SizedBox(height: 16),
              _buildTextField(
                  passwordController, "Mật khẩu", Icons.lock, true),
              const SizedBox(height: 20),

              // ---------- LOGIN BUTTON ----------
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 5,
                ),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text("ĐĂNG NHẬP"),
              ),

              const SizedBox(height: 16),

              // ---------- FOOTER LINKS ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _goToForgotPassword,
                    child: const Text(
                      "Quên mật khẩu?",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: _goToRegister,
                    child: const Text(
                      "Đăng ký",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- TEXTFIELD -------------------
  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon,
      bool isPassword,
      ) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isPassword ? TextInputType.text : TextInputType.phone,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off
                : Icons.visibility,
            color: theme.colorScheme.secondary,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        )
            : null,
      ),
    );
  }
}
