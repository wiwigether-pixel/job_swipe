import 'package:flutter/material.dart';
import 'dart:math' as math;

class ConnectionPainter extends CustomPainter {
  final double progress; // 動畫進度 (0.0 ~ 1.0)
  final Color activeColor; // 根據角色變化的顏色

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

    // 定義兩個虛擬節點位置 (對應人才與企業)
    final leftNode = Offset(size.width * 0.15, size.height * 0.3);
    final rightNode = Offset(size.width * 0.85, size.height * 0.7);

    // 畫背景流動感漸層線
    if (progress > 0.1) {
      final double lineProgress = math.min(1.0, (progress - 0.1) / 0.9);
      
      linePaint.shader = LinearGradient(
        colors: [activeColor.withOpacity(0.1), activeColor, activeColor.withOpacity(0.1)],
        stops: [0.0, lineProgress, 1.0],
      ).createShader(Rect.fromPoints(leftNode, rightNode));

      final path = Path();
      path.moveTo(leftNode.dx, leftNode.dy);
      
      // 優雅的 S 型曲線
      path.cubicTo(
        size.width * 0.5, leftNode.dy, 
        size.width * 0.5, rightNode.dy, 
        rightNode.dx, rightNode.dy,
      );

      canvas.drawPath(path, linePaint);
    }
    
    // 畫點綴的發光圓圈
    final circlePaint = Paint()..color = activeColor.withOpacity(0.3 * progress);
    canvas.drawCircle(leftNode, 20 * progress, circlePaint);
    canvas.drawCircle(rightNode, 20 * progress, circlePaint);
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.activeColor != activeColor;
  }
}