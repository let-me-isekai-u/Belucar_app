import 'package:flutter/material.dart';

import 'ui/brand.dart';

export 'ui/brand.dart';

/// Tên màu cũ (theme xanh lá) — giữ để code cũ còn biên dịch, đã trỏ sang bộ màu navy mới.
/// Code mới dùng [Brand] trực tiếp.
class AppColors {
  static const Color primaryGreen = Brand.navy;
  static const Color darkGreenBg = Brand.b950;
  static const Color accentGold = Brand.lane;
  static const Color brightYellow = Brand.lane;
  static const Color surfaceGreen = Brand.b800;
  static const Color textWhite = Colors.white;
  static const Color textSubtle = Brand.b200;
}

class AppTheme {
  static ThemeData get theme => Brand.theme();
}
