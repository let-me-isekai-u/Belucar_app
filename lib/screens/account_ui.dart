import 'package:flutter/material.dart';

import '../ui/ui.dart';
import 'booking/booking_ui.dart' show toneForLegacyColor;

/// Khung các màn tài khoản: nền xám sáng, AppBar trắng.
class AccountScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  const AccountScaffold({super.key, this.appBar, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.canvas,
      appBar: appBar,
      body: SafeArea(top: appBar == null, child: body),
    );
  }
}

class AccountSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const AccountSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconTile(icon, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(color: Brand.inkMuted, fontSize: 13, height: 1.35)),
                ],
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class AccountInfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const AccountInfoBanner({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.color});

  @override
  Widget build(BuildContext context) => InfoBanner(text, tone: toneForLegacyColor(color), icon: icon);
}

InputDecoration accountInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  Widget? suffixIcon,
  String? hint,
}) {
  return InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: Brand.navy), suffixIcon: suffixIcon);
}
