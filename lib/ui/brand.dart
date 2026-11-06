// Bộ nhận diện dùng chung với website (frontend/src/styles/index.css của backend):
// navy #041565 mang thương hiệu + hành động chính, nền xám sáng, vàng "vạch đường" chỉ để nhấn.
// Dùng các token này thay cho mã màu rời rạc trong màn hình.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Brand {
  Brand._();

  static const Color b50 = Color(0xFFEEF1FB);
  static const Color b100 = Color(0xFFDCE2F6);
  static const Color b200 = Color(0xFFB9C4EC);
  static const Color b300 = Color(0xFF8C9DDC);
  static const Color b400 = Color(0xFF5A70C6);
  static const Color b500 = Color(0xFF3049A8);
  static const Color b600 = Color(0xFF1A318C);
  static const Color b700 = Color(0xFF0F2478);
  static const Color b800 = Color(0xFF091C6C);
  static const Color navy = Color(0xFF041565);
  static const Color b950 = Color(0xFF020B3D);

  static const Color lane300 = Color(0xFFFFD866);
  static const Color lane = Color(0xFFFCC419);
  static const Color lane500 = Color(0xFFF5B301);

  static const Color canvas = Color(0xFFF4F5F8);
  static const Color surface = Colors.white;
  static const Color line = Color(0xFFE3E6EE);
  static const Color lineSoft = Color(0xFFEEF0F5);
  static const Color ink = Color(0xFF0B1033);
  static const Color inkMuted = Color(0xFF545B78);
  static const Color inkSubtle = Color(0xFF8A90A8);
  static const Color mapLand = Color(0xFFE8ECF2);

  static const Color success = Color(0xFF0F8A4A);
  static const Color success50 = Color(0xFFECFDF3);
  static const Color warning = Color(0xFF8A5300);
  static const Color warning50 = Color(0xFFFFF8E6);
  static const Color danger = Color(0xFFC62828);
  static const Color danger50 = Color(0xFFFEF1F1);
  static const Color info = Color(0xFF1D5FD1);
  static const Color info50 = Color(0xFFEEF6FF);

  static const String font = 'BeVietnamPro';

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0A041565), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F041565), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> floatShadow = [
    BoxShadow(color: Color(0x1F041565), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> sheetShadow = [
    BoxShadow(color: Color(0x1A041565), blurRadius: 30, offset: Offset(0, -8)),
  ];
  static const List<BoxShadow> ctaShadow = [
    BoxShadow(color: Color(0x40041565), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static BorderRadius r(double v) => BorderRadius.circular(v);

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: navy,
      onPrimary: Colors.white,
      primaryContainer: b50,
      onPrimaryContainer: navy,
      secondary: lane,
      onSecondary: navy,
      secondaryContainer: warning50,
      onSecondaryContainer: warning,
      tertiary: b500,
      onTertiary: Colors.white,
      error: danger,
      onError: Colors.white,
      errorContainer: danger50,
      onErrorContainer: danger,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: canvas,
      surfaceContainer: canvas,
      surfaceContainerHigh: b50,
      surfaceContainerHighest: b50,
      outline: line,
      outlineVariant: lineSoft,
      shadow: Color(0x33041565),
      inverseSurface: ink,
      onInverseSurface: Colors.white,
      inversePrimary: b200,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: font);
    final text = base.textTheme.apply(bodyColor: ink, displayColor: ink, fontFamily: font).copyWith(
          displayMedium: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4, color: ink),
          headlineLarge: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3, color: ink),
          headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25, color: ink),
          titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
          titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ink),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: ink),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: ink),
          bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: inkMuted),
          labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inkMuted),
          labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: inkMuted),
        );

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const buttonText = TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w700);
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: const DividerThemeData(color: lineSoft, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: navy),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: line,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: navy),
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700, color: ink),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: b100,
          disabledForegroundColor: b400,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: b100,
          disabledForegroundColor: b400,
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: b100, width: 1.5),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: buttonShape,
          textStyle: buttonText.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: b600,
          textStyle: const TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvas,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(navy, 1.5),
        errorBorder: border(danger),
        focusedErrorBorder: border(danger, 1.5),
        labelStyle: const TextStyle(color: inkMuted, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: navy, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: inkSubtle),
        prefixIconColor: navy,
        suffixIconColor: inkMuted,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: navy,
        side: const BorderSide(color: line, width: 1.5),
        labelStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600, color: ink, fontSize: 13),
        secondaryLabelStyle: const TextStyle(fontFamily: font, fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
        shape: const StadiumBorder(),
        checkmarkColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(fontFamily: font, color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        contentTextStyle: const TextStyle(fontFamily: font, fontSize: 14, height: 1.5, color: inkMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Color(0xFFD3D7E3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: navy,
        unselectedItemColor: inkMuted,
        selectedLabelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: navy,
        unselectedLabelColor: inkMuted,
        indicatorColor: navy,
        dividerColor: lineSoft,
        labelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: navy, linearTrackColor: b100),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? success : b200),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? navy : Colors.transparent),
        side: const BorderSide(color: b300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? navy : b300)),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: navy,
        headerForegroundColor: Colors.white,
      ),
      timePickerTheme: const TimePickerThemeData(backgroundColor: surface),
      listTileTheme: const ListTileThemeData(iconColor: navy, textColor: ink),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
