import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/ui.dart';

/// Khung màn đăng nhập/đăng ký: dải navy phía trên có vạch đường vàng, nội dung trên nền xám sáng.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  final double bandHeight;

  const AuthScaffold({super.key, required this.child, this.bandHeight = 320});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: Brand.canvas,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: bandHeight,
            child: const ColoredBox(color: Brand.navy),
          ),
          SafeArea(child: child),
        ],
      ),
    ),
    );
  }
}

class AuthPanel extends StatelessWidget {
  final Widget child;

  const AuthPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x29041565), blurRadius: 40, offset: Offset(0, 12))],
      ),
      child: child,
    );
  }
}

/// Logo + tiêu đề trên dải navy. [assetPath] giữ cho tương thích; logo dùng BrandMark của website.
class AuthLogoHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetPath;
  final Widget? trailing;

  const AuthLogoHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: const BrandMark(size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Đông Dương', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Xe ghép · Limousine · Xe khách', style: TextStyle(color: Brand.b200, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 22),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Brand.b100, fontSize: 14, height: 1.45)),
        ],
      ],
    );
  }
}

class AuthSectionLabel extends StatelessWidget {
  final String text;

  const AuthSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: FieldLabel(text, color: Brand.b500));
}

InputDecoration authInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  Widget? suffixIcon,
  String? hint,
}) {
  return InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: Brand.navy), suffixIcon: suffixIcon);
}

/// Chip thông tin nhỏ đặt trên dải navy.
class AuthInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const AuthInfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Brand.lane),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}
