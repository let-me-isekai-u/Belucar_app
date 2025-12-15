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


  //LOGIN API CALL
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
    final mediaQuery = MediaQuery.of(context);
    // Chiều cao cần thiết cho phần background/banner màu chính
    final backgroundHeight = mediaQuery.size.height * 0.35;

    return Scaffold(
      // Bỏ backgroundColor ở đây, sẽ dùng Stack để tạo hiệu ứng lớp
      body: Stack(
        children: [
          // 1. PHẦN BACKGROUND MÀU CHỦ ĐẠO (BANNER TOP)
          Container(
            height: backgroundHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50), // Bo góc lớn
                bottomRight: Radius.circular(50),
              ),
            ),
          ),

          // 2. NỘI DUNG (Center)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 50, left: 32, right: 32, bottom: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 2.1 LOGO VÀ TEXT (Hiển thị ngay trên nền màu chính)
                  _buildLogoSection(theme),
                  const SizedBox(height: 40),

                  // 2.2 FORM LOGIN (Bên trong Card nổi bật)
                  _buildLoginFormCard(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //WIDGET CON

// Logo và Tên ứng dụng
  Widget _buildLogoSection(ThemeData theme) {
    return Column(
      children: [
        // ---------- LOGO ----------
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(
              parent: _logoController,
              curve: Curves.easeInOut,
            ),
          ),
          child: Container(
            width: 120, // Kích thước nhỏ hơn 1 chút
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), // Bo góc nhiều hơn
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

        const SizedBox(height: 16),


      ],
    );
  }

// Form Login trong Card
  Widget _buildLoginFormCard(ThemeData theme) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Bo góc lớn
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // THÊM TEXT TẠI ĐÂY VỚI MÀU CHỦ ĐẠO
            Text(
              "Đăng nhập BeluCar",
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 28,
                color: theme.colorScheme.primary, // Dùng màu chủ đạo
              ) ??
                  const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                  ),
            ),
            const SizedBox(height: 10),

            // Tiêu đề form
            Text(
              "Tiếp tục hành trình của bạn",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600, // Làm mờ đi
              ),
            ),
            const SizedBox(height: 24),

            // ---------- INPUTS ----------
            _buildTextField(
              phoneController,
              "Số điện thoại",
              Icons.phone,
              false,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              passwordController,
              "Mật khẩu",
              Icons.lock,
              true,
            ),
            const SizedBox(height: 24),

            // ---------- LOGIN BUTTON ----------
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                minimumSize: const Size(double.infinity, 50),
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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


            Row(
              // Sử dụng spaceBetween để tối đa hóa khoảng cách giữa hai nút
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bọc bằng Expanded để nút Quên mật khẩu chiếm 1 phần không gian
                Expanded(
                  child: TextButton(
                    onPressed: _goToForgotPassword,
                    child: Text(
                      "Quên mật khẩu?",
                      style: TextStyle(color: theme.colorScheme.primary),
                      textAlign: TextAlign.start, // Căn lề trái
                    ),
                  ),
                ),
                const SizedBox(width: 8), // Thêm khoảng cách nhỏ giữa 2 nút
                // Bọc bằng Expanded để nút Đăng ký chiếm 1 phần không gian
                Expanded(
                  child: TextButton(
                    onPressed: _goToRegister,
                    child: Text(
                      "Đăng ký Tài khoản",
                      style: TextStyle(color: theme.colorScheme.secondary),
                      textAlign: TextAlign.end, // Căn lề phải
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Cập nhật lại TextField để có nền trắng, bo góc
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
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        labelText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        // Cải tiến: Thêm fill color và bo góc
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, // Bỏ đường viền mặc định
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
