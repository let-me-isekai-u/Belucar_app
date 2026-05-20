import 'package:flutter/material.dart';

import '../app_theme.dart';

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
    final innerRadius = (borderRadius - padding).clamp(0.0, borderRadius);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3D0), AppColors.accentGold],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: ColoredBox(
          color: AppColors.primaryGreen,
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
