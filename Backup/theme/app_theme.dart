import 'package:flutter/material.dart';

class AppColors{
  static const Color primary = Color(0xFF4CD7A7);
  static const Color primaryDark = Color(0xFF2BB38A);
  static const Color background = Color(0xFFF7FBFA);   // Gần trắng
  static const Color textDark = Color(0xFF2F2F2F);
  static const Color textLight = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get theme{
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        background: AppColors.background,
      ),

      scaffoldBackgroundColor: AppColors.background,

      ///App bar///
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 5,
        iconTheme: IconThemeData(color: AppColors.textLight),
        titleTextStyle: TextStyle(
          color: AppColors.textLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),

      ///Elevated button///
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
        ),
      ),

      ///Textfield///
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      ///Default Text Style
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: AppColors.textDark),
        bodyLarge: TextStyle(color: AppColors.textDark, fontSize: 16),
      ),
    );
  }
}