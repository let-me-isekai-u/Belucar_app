// Thành phần giao diện dùng chung (thẻ, chip trạng thái, mốc lộ trình, nút trượt, marker bản đồ...).
import 'package:flutter/material.dart';

import 'brand.dart';

/// Logo "ĐD" của Đông Dương (vẽ lại từ mark.svg của website) — không cần file ảnh.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color = Brand.navy, this.lane = Brand.lane});
  final double size;
  final Color color;
  final Color lane;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size * 400 / 280, size), painter: _BrandMarkPainter(color, lane));
}

class _BrandMarkPainter extends CustomPainter {
  _BrandMarkPainter(this.color, this.lane);
  final Color color;
  final Color lane;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 400, size.height / 280);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeJoin = StrokeJoin.miter;
    final d1 = Path()
      ..moveTo(60, 10)
      ..lineTo(156, 10)
      ..arcToPoint(const Offset(156, 264), radius: const Radius.elliptical(100, 127))
      ..lineTo(60, 264)
      ..close();
    final d2 = Path()
      ..moveTo(212, 10)
      ..lineTo(286, 10)
      ..arcToPoint(const Offset(286, 264), radius: const Radius.elliptical(101, 127))
      ..lineTo(212, 264);
    canvas.drawPath(d1, stroke);
    canvas.drawPath(d2, stroke);
    final fill = Paint()..color = color;
    canvas.drawPath(
        Path()
          ..moveTo(189, 54)
          ..lineTo(208, 72)
          ..lineTo(208, 206)
          ..lineTo(189, 221)
          ..close(),
        fill);
    canvas.drawRect(const Rect.fromLTWH(0, 139, 166, 21), Paint()..color = lane);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => old.color != color || old.lane != lane;
}

enum Tone { brand, success, warning, danger, info, neutral, lane }

(Color bg, Color fg) toneColors(Tone t) => switch (t) {
      Tone.brand => (Brand.b50, Brand.navy),
      Tone.success => (Brand.success50, Brand.success),
      Tone.warning => (Brand.warning50, Brand.warning),
      Tone.danger => (Brand.danger50, Brand.danger),
      Tone.info => (Brand.info50, Brand.info),
      Tone.neutral => (Brand.canvas, Brand.inkMuted),
      Tone.lane => (Brand.lane, Brand.navy),
    };

/// Chip trạng thái: màu nền nhạt + chữ đậm (không chỉ dựa vào màu).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = Tone.brand, this.icon, this.dense = false});
  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: fg, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Thẻ trắng bo 20px có bóng navy nhẹ. [highlight] vẽ viền (ví dụ vàng cho lựa chọn nổi bật).
class BrandCard extends StatelessWidget {
  const BrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlight,
    this.radius = 20,
    this.color = Brand.surface,
    this.shadow = true,
    this.margin,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? highlight;
  final double radius;
  final Color color;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: r,
        boxShadow: shadow ? Brand.cardShadow : null,
        border: highlight != null ? Border.all(color: highlight!, width: 2) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: r, onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Ô lựa chọn có viền (loại xe, phương thức...) — chọn thì viền navy + nền brand-50.
class SelectTile extends StatelessWidget {
  const SelectTile({super.key, required this.selected, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});
  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(16);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? Brand.b50 : Brand.surface,
        borderRadius: r,
        border: Border.all(color: selected ? Brand.navy : Brand.line, width: selected ? 2 : 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: r, onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.only(bottom: 8)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(action!),
            ),
        ]),
      );
}

/// Nhãn nhỏ viết hoa phía trên giá trị (ĐIỂM ĐÓN, SỐ KHÁCH...).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.color = Brand.inkMuted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: color));
}

/// Ô vuông bo góc chứa icon.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.bg = Brand.b50, this.fg = Brand.navy, this.radius = 12});
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        alignment: Alignment.center,
        child: Icon(icon, color: fg, size: size * 0.5),
      );
}

/// Chấm điểm đón (tròn navy) và điểm trả (vuông vàng viền navy) — dùng thống nhất cả list lẫn bản đồ.
class PickupDot extends StatelessWidget {
  const PickupDot({super.key, this.size = 10, this.hollow = false});
  final double size;
  final bool hollow;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hollow ? Colors.white : Brand.navy,
          border: hollow ? Border.all(color: Brand.navy, width: size * 0.28) : null,
        ),
      );
}

class DropoffDot extends StatelessWidget {
  const DropoffDot({super.key, this.size = 11});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Brand.lane,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: Brand.navy, width: 2),
        ),
      );
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key, this.axis = Axis.vertical, this.color = Brand.b300, this.dash = 4, this.gap = 3, this.thickness = 2});
  final Axis axis;
  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final length = axis == Axis.vertical ? c.maxHeight : c.maxWidth;
        if (!length.isFinite) return const SizedBox.shrink();
        final count = (length / (dash + gap)).floor().clamp(1, 400);
        final seg = Container(
          width: axis == Axis.vertical ? thickness : dash,
          height: axis == Axis.vertical ? dash : thickness,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        );
        return Flex(
          direction: axis,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) => seg),
        );
      });
}

class RouteStop {
  const RouteStop({required this.label, required this.title, this.subtitle, this.trailing, this.onTap});
  final String label;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
}

/// Khối điểm đón → điểm trả có trục chấm-gạch-vuông bên trái.
class RouteStops extends StatelessWidget {
  const RouteStops({super.key, required this.from, required this.to, this.background = Brand.canvas, this.padding = const EdgeInsets.all(14)});
  final RouteStop from;
  final RouteStop to;
  final Color background;
  final EdgeInsetsGeometry padding;

  Widget _row(RouteStop s) => InkWell(
        onTap: s.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FieldLabel(s.label),
                const SizedBox(height: 2),
                Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (s.subtitle != null && s.subtitle!.isNotEmpty)
                  Text(s.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkMuted)),
              ]),
            ),
            if (s.trailing != null) s.trailing!,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 20, right: 12),
              child: Column(children: [
                PickupDot(),
                Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: DashedLine())),
                DropoffDot(),
              ]),
            ),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _row(from),
                const SizedBox(height: 12),
                _row(to),
              ]),
            ),
          ]),
        ),
      );
}

/// Trục giờ đi → giờ đến (thẻ chuyến đường dài).
class TripTimeline extends StatelessWidget {
  const TripTimeline({super.key, required this.departTime, required this.departPlace, required this.arriveTime, required this.arrivePlace, this.duration});
  final String departTime;
  final String departPlace;
  final String arriveTime;
  final String arrivePlace;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    Widget end(String t, String p, CrossAxisAlignment a) => Column(crossAxisAlignment: a, children: [
          Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Brand.inkMuted)),
          ),
        ]);
    return Row(children: [
      end(departTime, departPlace, CrossAxisAlignment.start),
      const SizedBox(width: 10),
      Expanded(
        child: Row(children: [
          const PickupDot(size: 9, hollow: true),
          const SizedBox(width: 4),
          const Expanded(child: SizedBox(height: 2, child: DashedLine(axis: Axis.horizontal, color: Brand.navy, dash: 6, gap: 4))),
          if (duration != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(duration!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Brand.inkMuted)),
            ),
          if (duration != null)
            const Expanded(child: SizedBox(height: 2, child: DashedLine(axis: Axis.horizontal, color: Brand.navy, dash: 6, gap: 4))),
          const SizedBox(width: 4),
          const PickupDot(size: 9),
        ]),
      ),
      const SizedBox(width: 10),
      end(arriveTime, arrivePlace, CrossAxisAlignment.end),
    ]);
  }
}

/// Nút chính kiểu CTA ở đáy màn: nhãn trái, giá trị (giá) phải màu vàng.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({super.key, required this.label, this.onPressed, this.trailing, this.loading = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final String? trailing;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: enabled ? Brand.ctaShadow : null),
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Row(children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Expanded(child: Text(label, textAlign: trailing == null ? TextAlign.center : TextAlign.start)),
                if (trailing != null) Text(trailing!, style: const TextStyle(color: Brand.lane, fontWeight: FontWeight.w800)),
              ]),
      ),
    );
  }
}

/// Nút tròn nổi trên bản đồ (quay lại, vị trí của tôi, thông báo).
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.size = 46, this.square = false, this.badge = false});
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final bool square;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(square ? 14 : size);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white, borderRadius: r, boxShadow: Brand.floatShadow),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: onPressed,
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, color: Brand.navy, size: 22),
              if (badge)
                Positioned(
                  top: size * 0.24,
                  right: size * 0.26,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: Brand.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Panel trắng bo trên 28px nằm đè lên bản đồ.
class SheetPanel extends StatelessWidget {
  const SheetPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 16), this.color = Brand.surface});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: Brand.sheetShadow,
        ),
        padding: padding,
        child: child,
      );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD3D7E3), borderRadius: BorderRadius.circular(4))),
      );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.tone = Tone.warning, this.icon = Icons.info_outline_rounded, this.action});
  final String text;
  final Tone tone;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: fg == Brand.navy ? Brand.ink : fg, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500))),
        if (action != null) action!,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconTile(icon, size: 64, radius: 20),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Brand.inkMuted, height: 1.45)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Nút trượt để xác nhận thao tác quan trọng (bắt đầu/hoàn thành chuyến).
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({super.key, required this.label, required this.onConfirmed, this.enabled = true, this.color = Brand.navy});
  final String label;
  final Future<void> Function() onConfirmed;
  final bool enabled;
  final Color color;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> {
  double _dx = 0;
  bool _busy = false;
  static const double _h = 58;
  static const double _knob = 48;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final max = c.maxWidth - _knob - 10;
        final progress = max <= 0 ? 0.0 : (_dx / max).clamp(0.0, 1.0);
        return Semantics(
          button: true,
          label: widget.label,
          onTap: widget.enabled && !_busy ? _fire : null,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: Container(
              height: _h,
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(999)),
              child: Stack(alignment: Alignment.centerLeft, children: [
                Center(
                  child: Opacity(
                    opacity: 1 - progress * 0.8,
                    child: Padding(
                      padding: const EdgeInsets.only(left: _knob),
                      child: Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                Positioned(
                  left: 5 + _dx,
                  child: GestureDetector(
                    onHorizontalDragUpdate: widget.enabled && !_busy ? (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(0, max)) : null,
                    onHorizontalDragEnd: widget.enabled && !_busy
                        ? (_) {
                            if (progress > 0.85) {
                              _fire();
                            } else {
                              setState(() => _dx = 0);
                            }
                          }
                        : null,
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: const BoxDecoration(color: Brand.lane, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Brand.navy))
                          : const Icon(Icons.arrow_forward_rounded, color: Brand.navy),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      });

  Future<void> _fire() async {
    setState(() => _busy = true);
    try {
      await widget.onConfirmed();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _dx = 0;
        });
      }
    }
  }
}

/// Marker xe trên bản đồ (ô navy có mũi tên vàng, xoay theo hướng).
class VehicleMarker extends StatelessWidget {
  const VehicleMarker({super.key, this.heading = 0, this.size = 34});
  final double heading;
  final double size;
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: heading * 3.1415926535 / 180,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Brand.navy,
            borderRadius: BorderRadius.circular(size * 0.35),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x66041565), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Icon(Icons.navigation_rounded, color: Brand.lane, size: size * 0.5),
        ),
      );
}

/// Marker điểm đón (tròn navy viền trắng) / điểm trả (vuông vàng viền navy) trên bản đồ.
class PlaceMarker extends StatelessWidget {
  const PlaceMarker.pickup({super.key}) : dropoff = false;
  const PlaceMarker.dropoff({super.key}) : dropoff = true;
  final bool dropoff;
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: dropoff ? Brand.lane : Brand.navy,
          borderRadius: BorderRadius.circular(dropoff ? 6 : 12),
          border: Border.all(color: dropoff ? Brand.navy : Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Color(0x55041565), blurRadius: 8, offset: Offset(0, 2))],
        ),
      );
}

/// Chấm vị trí của tôi (có quầng).
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Brand.navy.withValues(alpha: 0.15), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: Brand.navy, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
        ),
      );
}

/// Bộ tăng/giảm số lượng.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 10});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(Icons.remove_rounded, 'Bớt', value > min ? () => onChanged(value - 1) : null, false),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        _btn(Icons.add_rounded, 'Thêm', value < max ? () => onChanged(value + 1) : null, true),
      ]);

  Widget _btn(IconData i, String tip, VoidCallback? onTap, bool primary) => Tooltip(
        message: tip,
        child: Material(
          color: onTap == null ? Brand.b50 : (primary ? Brand.navy : Colors.white),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(i, color: onTap == null ? Brand.b300 : (primary ? Colors.white : Brand.navy)),
            ),
          ),
        ),
      );
}
