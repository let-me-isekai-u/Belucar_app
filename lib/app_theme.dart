import 'package:flutter/material.dart';

class AppColors {
  // Màu chủ đạo chuyển sang Đỏ Tết (Lucky Red) thay vì xanh lá
  static const Color primary = Color(0xFFD32F2F);
  static const Color primaryDark = Color(0xFFB71C1C);

  // Màu vàng đồng/vàng mai cho các chi tiết nhấn (Accent)
  static const Color festiveGold = Color(0xFFFFD700);

  // Màu hồng hoa đào cho các nút hoặc background nhẹ
  static const Color peachBlossom = Color(0xFFFFB7C5);

  // Nền trắng ngà (Ivory) tạo cảm giác ấm cúng hơn trắng tinh
  static const Color background = Color(0xFFFFF9F0);

  static const Color textDark = Color(0xFF3E2723); // Nâu đậm gỗ thay vì đen xám
  static const Color textLight = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.festiveGold,
        surface: AppColors.background,
        background: AppColors.background,
      ),

      scaffoldBackgroundColor: AppColors.background,

      /// App Bar: Tạo điểm nhấn mạnh với màu đỏ và chữ vàng nhẹ
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        centerTitle: true, // Thường app Tết để center nhìn cân đối hơn
        elevation: 2,
        shadowColor: Color(0x40D32F2F),
        iconTheme: IconThemeData(color: AppColors.festiveGold),
        titleTextStyle: TextStyle(
          color: AppColors.festiveGold,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),

      /// Elevated Button: Bo tròn hơn và có bóng đổ sống động
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.festiveGold,
          elevation: 4,
          shadowColor: Colors.redAccent.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Bo tròn mềm mại hơn
            side: const BorderSide(color: AppColors.festiveGold, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      /// TextField: Nền trắng, viền đỏ khi focus
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),

      /// Default Text Style: Chuyển sang tông nâu ấm
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textDark),
        bodyLarge: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w500),
        headlineMedium: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
      ),

      /// Card Theme: Thêm chút không khí Tết cho các khung thông tin
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        surfaceTintColor: AppColors.peachBlossom,
      ),
    );
  }
}