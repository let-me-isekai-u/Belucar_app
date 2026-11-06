import 'package:flutter/material.dart';

import '../ui/ui.dart';

/// Huy hiệu logo: ô trắng bo góc chứa logo "ĐD" của website.
/// [assetPath] giữ để tương thích chỗ gọi cũ (không còn dùng ảnh).
class BrandLogoBadge extends StatelessWidget {
  final String assetPath;
  final double size;
  final double borderRadius;
  final double padding;

  const BrandLogoBadge({
    super.key,
    required this.assetPath,
    this.size = 82,
    this.borderRadius = 24,
    this.padding = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(borderRadius), boxShadow: Brand.floatShadow),
      alignment: Alignment.center,
      child: BrandMark(size: size * 0.46),
    );
  }
}
