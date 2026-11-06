import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Nền luồng đặt xe: xám sáng, nội dung trong SafeArea.
class BookingFlowBackground extends StatelessWidget {
  final Widget child;

  const BookingFlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(color: Brand.canvas, child: SafeArea(child: child));
}

class BookingKeyboardDismissArea extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BookingKeyboardDismissArea({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap?.call();
      },
      child: child,
    );
  }
}

/// Thanh hành động đáy: nền trắng, bóng nhẹ, tự đẩy lên khi bàn phím mở.
class BookingBottomActionBar extends StatelessWidget {
  final Widget child;

  const BookingBottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Brand.surface,
          boxShadow: [BoxShadow(color: Color(0x14041565), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

/// Đầu mỗi bước đặt xe: thanh tiến trình + tiêu đề.
class BookingStepHero extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final String? assetPath;
  final Widget? footer;

  const BookingStepHero({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    this.totalSteps = 3,
    this.assetPath,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          for (var i = 1; i <= totalSteps; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                decoration: BoxDecoration(color: i <= step ? Brand.navy : Brand.b100, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (i < totalSteps) const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 14),
        FieldLabel('Bước $step/$totalSteps', color: Brand.b500),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: Brand.inkMuted, height: 1.45)),
        if (footer != null) ...[const SizedBox(height: 14), footer!],
      ],
    );
  }
}

class BookingSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final Widget child;

  const BookingSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconTile(icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: const TextStyle(fontSize: 12, color: Brand.inkMuted, height: 1.35)),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Tone theo màu cũ được truyền vào: đỏ → lỗi, xanh lá → thành công, màu khác → cảnh báo, không truyền → thông tin.
Tone toneForLegacyColor(Color? c) {
  if (c == null) return Tone.info;
  final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
  if (r > 180 && g < 120 && b < 120) return Tone.danger;
  if (g > r && g > b) return Tone.success;
  return Tone.warning;
}

class BookingInfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const BookingInfoBanner({super.key, required this.text, this.icon = Icons.info_outline, this.color});

  @override
  Widget build(BuildContext context) => InfoBanner(text, tone: toneForLegacyColor(color), icon: icon);
}

class BookingSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const BookingSummaryChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Brand.navy),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: const TextStyle(color: Brand.ink, fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}

InputDecoration bookingInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: Brand.navy),
    suffixIcon: suffixIcon,
  );
}

void dismissBookingKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
}
