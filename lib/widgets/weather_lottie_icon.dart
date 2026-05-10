import 'package:flutter/material.dart';
import 'dart:math' as math;

class WeatherLottieIcon extends StatefulWidget {
  final int weatherCode;
  final bool isDay;
  final double size;
  final String? customDescription;

  const WeatherLottieIcon({
    Key? key,
    required this.weatherCode,
    this.isDay = true,
    this.size = 80,
    this.customDescription,
  }) : super(key: key);

  @override
  State<WeatherLottieIcon> createState() => _WeatherLottieIconState();
}

class _WeatherLottieIconState extends State<WeatherLottieIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: WeatherIconPainter(
            weatherCode: widget.weatherCode,
            isDay: widget.isDay,
            customDescription: widget.customDescription,
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class WeatherIconPainter extends CustomPainter {
  final int weatherCode;
  final bool isDay;
  final String? customDescription;
  final double animationValue;

  WeatherIconPainter({
    required this.weatherCode,
    required this.isDay,
    this.customDescription,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Handle custom METAR conditions
    if (customDescription != null && customDescription!.isNotEmpty) {
      final desc = customDescription!.toUpperCase();
      if (desc.contains('HAZE') || desc.contains('MIST')) {
        _paintHaze(canvas, center, radius);
        return;
      }
      if (desc.contains('SMOKE')) {
        _paintSmoke(canvas, center, radius);
        return;
      }
      if (desc.contains('DUST') ||
          desc.contains('SAND') ||
          desc.contains('TORNADO')) {
        _paintDustStorm(canvas, center, radius);
        return;
      }
      if (desc.contains('FOG')) {
        _paintFog(canvas, center, radius);
        return;
      }
    }

    switch (weatherCode) {
      case 0:
        // Clear sky
        if (isDay) {
          _paintSun(canvas, center, radius);
        } else {
          _paintMoon(canvas, center, radius);
        }
        break;
      case 1:
        // Mainly clear
        if (isDay) {
          _paintSun(canvas, center, radius);
        } else {
          _paintMoon(canvas, center, radius);
        }
        break;
      case 2:
        // Partly cloudy
        if (isDay) {
          _paintPartlyCloudyDay(canvas, center, radius);
        } else {
          _paintPartlyCloudyNight(canvas, center, radius);
        }
        break;
      case 3:
        // Overcast
        _paintCloudy(canvas, center, radius);
        break;
      case 45:
      case 48:
        // Foggy
        _paintFog(canvas, center, radius);
        break;
      case 51:
      case 53:
      case 55:
        // Drizzle
        _paintDrizzle(canvas, center, radius);
        break;
      case 61:
      case 63:
      case 65:
        // Rain
        _paintRain(canvas, center, radius);
        break;
      case 71:
      case 73:
      case 75:
      case 77:
        // Snow
        _paintSnow(canvas, center, radius);
        break;
      case 80:
      case 81:
      case 82:
        // Rain showers
        _paintRain(canvas, center, radius);
        break;
      case 85:
      case 86:
        // Snow showers
        _paintSnow(canvas, center, radius);
        break;
      case 95:
      case 96:
      case 99:
        // Thunderstorm
        _paintThunderstorm(canvas, center, radius);
        break;
      default:
        _paintCloudy(canvas, center, radius);
    }
  }

  void _paintSun(Canvas canvas, Offset center, double radius) {
    final sunRadius = radius * 0.6;
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, sunRadius, paint);

    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = radius * 0.1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final startRadius = sunRadius + radius * 0.15;
      final endRadius = sunRadius + radius * 0.3;
      final start = Offset(
        center.dx + startRadius * math.cos(angle),
        center.dy + startRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + endRadius * math.cos(angle),
        center.dy + endRadius * math.sin(angle),
      );
      canvas.drawLine(start, end, rayPaint);
    }
  }

  void _paintMoon(Canvas canvas, Offset center, double radius) {
    final moonRadius = radius * 0.6;
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, moonRadius, paint);

    final shadowPaint = Paint()
      ..color = const Color(0xFF1a1a2e)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx + moonRadius * 0.3, center.dy),
      moonRadius * 0.6,
      shadowPaint,
    );
  }

  void _paintPartlyCloudyDay(Canvas canvas, Offset center, double radius) {
    // Sun
    final sunCenter =
        Offset(center.dx - radius * 0.2, center.dy - radius * 0.2);
    final sunRadius = radius * 0.4;
    final sunPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Cloud
    _paintCloudShape(
        canvas,
        Offset(center.dx + radius * 0.1, center.dy + radius * 0.1),
        radius * 0.7);
  }

  void _paintPartlyCloudyNight(Canvas canvas, Offset center, double radius) {
    // Moon
    final moonCenter =
        Offset(center.dx - radius * 0.2, center.dy - radius * 0.2);
    final moonRadius = radius * 0.4;
    final moonPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);

    // Cloud
    _paintCloudShape(
        canvas,
        Offset(center.dx + radius * 0.1, center.dy + radius * 0.1),
        radius * 0.7);
  }

  void _paintCloudy(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(canvas, center, radius);
  }

  void _paintCloudShape(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx - size * 0.4, center.dy + size * 0.1);
    path.quadraticBezierTo(center.dx - size * 0.4, center.dy - size * 0.2,
        center.dx - size * 0.1, center.dy - size * 0.2);
    path.quadraticBezierTo(center.dx, center.dy - size * 0.35,
        center.dx + size * 0.2, center.dy - size * 0.2);
    path.quadraticBezierTo(center.dx + size * 0.4, center.dy - size * 0.2,
        center.dx + size * 0.4, center.dy + size * 0.1);
    path.lineTo(center.dx - size * 0.4, center.dy + size * 0.1);
    canvas.drawPath(path, paint);
  }

  void _paintRain(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(canvas, center, radius * 0.8);

    final rainPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..strokeWidth = radius * 0.08
      ..strokeCap = StrokeCap.round;

    final yOffset = (animationValue * radius * 0.4) - radius * 0.2;

    for (int i = 0; i < 3; i++) {
      final xOffset = center.dx - radius * 0.15 + (i * radius * 0.15);
      canvas.drawLine(
        Offset(xOffset, center.dy + radius * 0.15 + yOffset),
        Offset(xOffset - radius * 0.1, center.dy + radius * 0.3 + yOffset),
        rainPaint,
      );
    }
  }

  void _paintDrizzle(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(canvas, center, radius * 0.8);

    final drizzlePaint = Paint()
      ..color = const Color(0xFF81D4FA)
      ..strokeWidth = radius * 0.06
      ..strokeCap = StrokeCap.round;

    final yOffset = (animationValue * radius * 0.3) - radius * 0.15;

    for (int i = 0; i < 4; i++) {
      final xOffset = center.dx - radius * 0.2 + (i * radius * 0.13);
      canvas.drawLine(
        Offset(xOffset, center.dy + radius * 0.2 + yOffset),
        Offset(xOffset - radius * 0.08, center.dy + radius * 0.3 + yOffset),
        drizzlePaint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(canvas, center, radius * 0.8);

    final snowPaint = Paint()
      ..color = const Color(0xFFE0F7FA)
      ..style = PaintingStyle.fill;

    final yOffset = (animationValue * radius * 0.4) - radius * 0.2;

    for (int i = 0; i < 4; i++) {
      final xOffset = center.dx - radius * 0.2 + (i * radius * 0.13);
      canvas.drawCircle(
        Offset(xOffset, center.dy + radius * 0.15 + yOffset),
        radius * 0.06,
        snowPaint,
      );
    }
  }

  void _paintThunderstorm(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(canvas, center, radius * 0.9);

    // Lightning bolt
    if (animationValue > 0.5) {
      final lightningPaint = Paint()
        ..color = const Color(0xFFFFEB3B)
        ..strokeWidth = radius * 0.06
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(center.dx + radius * 0.15, center.dy - radius * 0.1);
      path.lineTo(center.dx + radius * 0.05, center.dy + radius * 0.1);
      path.lineTo(center.dx + radius * 0.2, center.dy + radius * 0.15);
      path.lineTo(center.dx, center.dy + radius * 0.35);

      canvas.drawPath(path, lightningPaint);
    }

    // Rain drops
    final rainPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..strokeWidth = radius * 0.06
      ..strokeCap = StrokeCap.round;

    final yOffset = (animationValue * radius * 0.3) - radius * 0.15;

    canvas.drawLine(
      Offset(center.dx - radius * 0.15, center.dy + radius * 0.25 + yOffset),
      Offset(center.dx - radius * 0.25, center.dy + radius * 0.35 + yOffset),
      rainPaint,
    );
  }

  void _paintFog(Canvas canvas, Offset center, double radius) {
    final fogPaint = Paint()
      ..color = const Color(0xFFB0BEC5).withOpacity(0.6 + animationValue * 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
                center.dx, center.dy - radius * 0.2 + (i * radius * 0.2)),
            width: radius * 1.4,
            height: radius * 0.2,
          ),
          Radius.circular(radius * 0.1),
        ),
        fogPaint,
      );
    }
  }

  void _paintHaze(Canvas canvas, Offset center, double radius) {
    final hazePaint = Paint()
      ..color = const Color(0xFFCCBC9B).withOpacity(0.5 + animationValue * 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, hazePaint);

    final outlinePaint = Paint()
      ..color = const Color(0xFFCCBC9B).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1;

    canvas.drawCircle(center, radius * 0.8, outlinePaint);
  }

  void _paintSmoke(Canvas canvas, Offset center, double radius) {
    final smokePaint = Paint()
      ..color = const Color(0xFF757575).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final yOffset = animationValue * radius * 0.3;
      canvas.drawCircle(
        Offset(center.dx - radius * 0.2 + (i * radius * 0.2),
            center.dy - radius * 0.1 - yOffset),
        radius * (0.3 - i * 0.08),
        smokePaint,
      );
    }
  }

  void _paintDustStorm(Canvas canvas, Offset center, double radius) {
    final dustPaint = Paint()
      ..color = const Color(0xFFCD853F).withOpacity(0.4 + animationValue * 0.3)
      ..style = PaintingStyle.fill;

    final angle = animationValue * 2 * math.pi;
    canvas.drawCircle(center, radius, dustPaint);

    final windPaint = Paint()
      ..color = const Color(0xFFCD853F).withOpacity(0.6)
      ..strokeWidth = radius * 0.1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(
          center.dx - radius * 0.4 + radius * 0.2 * math.cos(angle), center.dy),
      Offset(
          center.dx + radius * 0.4 + radius * 0.2 * math.cos(angle), center.dy),
      windPaint,
    );
  }

  @override
  bool shouldRepaint(WeatherIconPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.weatherCode != weatherCode ||
        oldDelegate.isDay != isDay;
  }
}
