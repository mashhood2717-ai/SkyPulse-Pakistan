import 'package:flutter/material.dart';
import 'dart:math' as math;

class WindCompass extends StatelessWidget {
  final double windSpeed;
  final double windDirection; // in degrees (0-360)

  const WindCompass({
    Key? key,
    required this.windSpeed,
    this.windDirection = 0 - 360, // Default to North
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CompassPainter(
        windDirection: windDirection,
        windSpeed: windSpeed,
      ),
      child: Container(),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double windDirection;
  final double windSpeed;

  CompassPainter({
    required this.windDirection,
    required this.windSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    final outerCirclePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, outerCirclePaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Color(0xFF66BB6A).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);

    // Draw cardinal directions
    _drawCardinalMarks(canvas, center, radius);

    // Draw wind direction arrow
    _drawWindArrow(canvas, center, radius);
  }

  void _drawCardinalMarks(Canvas canvas, Offset center, double radius) {
    final directions = ['N', 'E', 'S', 'W'];
    final angles = [0, 90, 180, 270];

    for (int i = 0; i < 4; i++) {
      final angle = angles[i] * math.pi / 180;
      final x = center.dx + (radius - 20) * math.sin(angle);
      final y = center.dy - (radius - 20) * math.cos(angle);

      final textSpan = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: i == 0 ? Color(0xFF66BB6A) : Colors.white70,
          fontSize: 14,
          fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w600,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  void _drawWindArrow(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(windDirection * math.pi / 180);

    // Arrow path
    final arrowPath = Path();
    final arrowLength = radius * 0.6;

    // Arrow pointing up (direction wind is going TO)
    arrowPath.moveTo(0, -arrowLength);
    arrowPath.lineTo(-8, -arrowLength + 15);
    arrowPath.lineTo(0, -arrowLength + 10);
    arrowPath.lineTo(8, -arrowLength + 15);
    arrowPath.close();

    // Draw arrow shaft
    final shaftPaint = Paint()
      ..color = Color(0xFF66BB6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, -arrowLength + 10),
      Offset(0, arrowLength * 0.3),
      shaftPaint,
    );

    // Draw arrow head
    final arrowPaint = Paint()
      ..color = Color(0xFF66BB6A)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);

    // Draw center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(0, 0), 4, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) {
    return oldDelegate.windDirection != windDirection ||
        oldDelegate.windSpeed != windSpeed;
  }
}
