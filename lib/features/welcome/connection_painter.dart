import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConnectionPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  ConnectionPainter({
    required this.progress,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final leftNode = Offset(size.width * 0.15, size.height * 0.3);
    final rightNode = Offset(size.width * 0.85, size.height * 0.7);

    if (progress > 0.1) {
      final double lineProgress = math.min(1.0, (progress - 0.1) / 0.9);

      linePaint.shader = LinearGradient(
        colors: [
          activeColor.withValues(alpha: 0.1),
          activeColor,
          activeColor.withValues(alpha: 0.1),
        ],
        stops: [0.0, lineProgress, 1.0],
      ).createShader(Rect.fromPoints(leftNode, rightNode));

      final path = Path();
      path.moveTo(leftNode.dx, leftNode.dy);
      path.cubicTo(
        size.width * 0.5, leftNode.dy,
        size.width * 0.5, rightNode.dy,
        rightNode.dx, rightNode.dy,
      );

      canvas.drawPath(path, linePaint);
    }

    final circlePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.3 * progress);
    canvas.drawCircle(leftNode, 20 * progress, circlePaint);
    canvas.drawCircle(rightNode, 20 * progress, circlePaint);
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}