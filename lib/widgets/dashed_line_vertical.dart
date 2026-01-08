import 'package:flutter/material.dart';

class DashedLineVertical extends StatelessWidget {
  final double height;
  final Color color;
  final double dashHeight;
  final double dashSpace;

  const DashedLineVertical({
    super.key,
    required this.height,
    this.color = Colors.grey,
    this.dashHeight = 4,
    this.dashSpace = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _DashedLineVerticalPainter(
          color: color,
          dashHeight: dashHeight,
          dashSpace: dashSpace,
        ),
      ),
    );
  }
}

class _DashedLineVerticalPainter extends CustomPainter {
  final Color color;
  final double dashHeight;
  final double dashSpace;

  _DashedLineVerticalPainter({
    required this.color,
    required this.dashHeight,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double startY = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
