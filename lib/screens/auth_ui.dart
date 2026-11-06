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

InputDecoration authInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  Widget? suffixIcon,
  String? hint,
}) {
  return InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: Brand.navy), suffixIcon: suffixIcon);
}
