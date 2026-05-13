import 'dart:math' as math;

import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 4200),
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: WeatherIconPainter(
              weatherCode: widget.weatherCode,
              isDay: widget.isDay,
              customDescription: widget.customDescription,
              animationValue: _controller.value,
            ),
          );
        },
      ),
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

  double get _wave => math.sin(animationValue * math.pi * 2);
  double get _pulse => 0.5 + (_wave * 0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side / 2;

    final desc = customDescription?.trim().toUpperCase() ?? '';
    if (desc.isNotEmpty) {
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
      if (_isWindOnlyDescription(desc)) {
        _paintBreezy(canvas, center, radius);
        return;
      }
    }

    switch (weatherCode) {
      case 0:
      case 1:
        isDay
            ? _paintSun(canvas, center, radius)
            : _paintMoon(canvas, center, radius);
        break;
      case 2:
        isDay
            ? _paintPartlyCloudyDay(canvas, center, radius)
            : _paintPartlyCloudyNight(canvas, center, radius);
        break;
      case 3:
        _paintCloudy(canvas, center, radius);
        break;
      case 45:
      case 48:
        _paintFog(canvas, center, radius);
        break;
      case 51:
      case 53:
      case 55:
        _paintDrizzle(canvas, center, radius);
        break;
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        _paintRain(canvas, center, radius);
        break;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        _paintSnow(canvas, center, radius);
        break;
      case 95:
      case 96:
      case 99:
        _paintThunderstorm(canvas, center, radius);
        break;
      default:
        _paintCloudy(canvas, center, radius);
    }
  }

  void _paintSun(Canvas canvas, Offset center, double radius) {
    final glowRadius = radius * (0.86 + _pulse * 0.04);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD166).withOpacity(0.38),
          const Color(0xFFFFD166).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0, 0.54, 1],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    final rayPaint = Paint()
      ..color = const Color(0xFFFFD166).withOpacity(0.32)
      ..strokeWidth = math.max(1.0, radius * 0.035)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 + animationValue * 12) * math.pi / 180;
      final start = radius * 0.52;
      final end = radius * 0.68;
      canvas.drawLine(
        Offset(center.dx + start * math.cos(angle),
            center.dy + start * math.sin(angle)),
        Offset(center.dx + end * math.cos(angle),
            center.dy + end * math.sin(angle)),
        rayPaint,
      );
    }

    _paintSunCore(canvas, center, radius * 0.42);
  }

  void _paintSunCore(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.45),
        colors: [
          Color(0xFFFFF4B0),
          Color(0xFFFFD166),
          Color(0xFFF59E3D),
        ],
        stops: [0, 0.56, 1],
      ).createShader(rect);

    canvas.drawShadow(
      Path()..addOval(rect),
      const Color(0xFFFFB703).withOpacity(0.35),
      radius * 0.18,
      true,
    );
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.28),
      radius * 0.26,
      Paint()..color = Colors.white.withOpacity(0.22),
    );
  }

  void _paintMoon(Canvas canvas, Offset center, double radius) {
    final moonRadius = radius * 0.47;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFBFD7FF).withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.86));
    canvas.drawCircle(center, radius * 0.86, glowPaint);

    final layerBounds = Rect.fromCircle(center: center, radius: radius);
    canvas.saveLayer(layerBounds, Paint());
    final moonPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFD8E7FF),
          Color(0xFF9FB7D9),
        ],
        stops: [0, 0.58, 1],
      ).createShader(Rect.fromCircle(center: center, radius: moonRadius));

    canvas.drawCircle(center, moonRadius, moonPaint);
    canvas.drawCircle(
      Offset(center.dx + moonRadius * 0.36, center.dy - moonRadius * 0.05),
      moonRadius * 0.82,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.55 + _pulse * 0.18)
      ..strokeWidth = math.max(1, radius * 0.018)
      ..strokeCap = StrokeCap.round;
    _paintStar(canvas, center + Offset(radius * 0.42, -radius * 0.34),
        radius * 0.07, starPaint);
    _paintStar(canvas, center + Offset(-radius * 0.46, radius * 0.22),
        radius * 0.05, starPaint);
  }

  void _paintPartlyCloudyDay(Canvas canvas, Offset center, double radius) {
    _paintSunCore(
      canvas,
      center + Offset(-radius * 0.22, -radius * 0.22),
      radius * 0.32,
    );
    _paintCloudShape(
      canvas,
      center + Offset(radius * 0.08, radius * 0.12),
      radius * 0.82,
    );
  }

  void _paintPartlyCloudyNight(Canvas canvas, Offset center, double radius) {
    _paintMoon(
        canvas, center + Offset(-radius * 0.22, -radius * 0.20), radius * 0.64);
    _paintCloudShape(
      canvas,
      center + Offset(radius * 0.10, radius * 0.14),
      radius * 0.80,
      dark: true,
    );
  }

  void _paintCloudy(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(canvas, center, radius * 0.96, dark: !isDay);
  }

  void _paintBreezy(Canvas canvas, Offset center, double radius) {
    if (isDay) {
      _paintSunCore(
        canvas,
        center + Offset(-radius * 0.28, -radius * 0.24),
        radius * 0.26,
      );
    } else {
      _paintMoon(
        canvas,
        center + Offset(-radius * 0.30, -radius * 0.25),
        radius * 0.54,
      );
    }

    _paintAtmosphericLines(
      canvas,
      center + Offset(radius * 0.08, radius * 0.05),
      radius,
      const Color(0xFFE5F4FF).withOpacity(0.72),
    );
  }

  void _paintRain(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(
      canvas,
      center + Offset(0, -radius * 0.10),
      radius * 0.88,
      dark: !isDay,
    );
    _paintRainLines(canvas, center, radius, count: 4, heavy: true);
  }

  void _paintDrizzle(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(
      canvas,
      center + Offset(0, -radius * 0.10),
      radius * 0.86,
      dark: !isDay,
    );
    _paintRainLines(canvas, center, radius, count: 5, heavy: false);
  }

  void _paintSnow(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(
      canvas,
      center + Offset(0, -radius * 0.10),
      radius * 0.88,
      dark: !isDay,
    );

    final paint = Paint()
      ..color = const Color(0xFFE8F7FF).withOpacity(0.88)
      ..strokeWidth = math.max(1, radius * 0.025)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final x = center.dx - radius * 0.34 + i * radius * 0.17;
      final phase = (animationValue + i * 0.18) % 1;
      final y = center.dy + radius * (0.18 + phase * 0.34);
      final size = radius * (0.04 + (i % 2) * 0.015);
      _paintStar(canvas, Offset(x, y), size, paint);
    }
  }

  void _paintThunderstorm(Canvas canvas, Offset center, double radius) {
    _paintCloudShape(
      canvas,
      center + Offset(0, -radius * 0.12),
      radius * 0.92,
      dark: true,
    );

    final flash = animationValue > 0.62 && animationValue < 0.78;
    final boltPaint = Paint()
      ..color = const Color(0xFFFFE066).withOpacity(flash ? 1 : 0.72)
      ..style = PaintingStyle.fill;

    final bolt = Path()
      ..moveTo(center.dx + radius * 0.04, center.dy + radius * 0.02)
      ..lineTo(center.dx - radius * 0.12, center.dy + radius * 0.34)
      ..lineTo(center.dx + radius * 0.05, center.dy + radius * 0.29)
      ..lineTo(center.dx - radius * 0.03, center.dy + radius * 0.58)
      ..lineTo(center.dx + radius * 0.26, center.dy + radius * 0.16)
      ..lineTo(center.dx + radius * 0.09, center.dy + radius * 0.20)
      ..close();

    canvas.drawShadow(
      bolt,
      const Color(0xFFFFE066).withOpacity(0.45),
      radius * (flash ? 0.22 : 0.10),
      true,
    );
    canvas.drawPath(bolt, boltPaint);
    _paintRainLines(canvas, center, radius, count: 3, heavy: false);
  }

  void _paintFog(Canvas canvas, Offset center, double radius) {
    final cloudCenter = center + Offset(0, -radius * 0.14);
    _paintCloudShape(canvas, cloudCenter, radius * 0.76, dark: !isDay);

    const baseLineColor = Color(0xFFE2ECF6);
    final linePaint = Paint()
      ..color = baseLineColor.withOpacity(0.54)
      ..strokeWidth = math.max(1.2, radius * 0.045)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final y = center.dy + radius * (0.10 + i * 0.16);
      final shift = _wave * radius * 0.05 * (i.isEven ? 1 : -1);
      canvas.drawLine(
        Offset(center.dx - radius * 0.58 + shift, y),
        Offset(center.dx + radius * 0.58 + shift, y),
        linePaint..color = baseLineColor.withOpacity(0.62 - i * 0.08),
      );
    }
  }

  void _paintHaze(Canvas canvas, Offset center, double radius) {
    final hazePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD68A).withOpacity(0.46),
          const Color(0xFFC7B48B).withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.94));

    canvas.drawCircle(center, radius * 0.94, hazePaint);
    _paintSunCore(
        canvas, center + Offset(-radius * 0.10, -radius * 0.08), radius * 0.28);
    _paintAtmosphericLines(
      canvas,
      center,
      radius,
      const Color(0xFFFFE6B3).withOpacity(0.54),
    );
  }

  void _paintSmoke(Canvas canvas, Offset center, double radius) {
    const smokeColor = Color(0xFFCBD5E1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.3, radius * 0.055)
      ..strokeCap = StrokeCap.round
      ..color = smokeColor.withOpacity(0.46);

    for (int i = 0; i < 4; i++) {
      final y = center.dy - radius * 0.28 + i * radius * 0.18;
      final path = Path()
        ..moveTo(center.dx - radius * 0.50, y)
        ..cubicTo(
          center.dx - radius * 0.18,
          y - radius * (0.12 + _pulse * 0.05),
          center.dx + radius * 0.18,
          y + radius * 0.12,
          center.dx + radius * 0.50,
          y,
        );
      canvas.drawPath(
          path, paint..color = smokeColor.withOpacity(0.5 - i * 0.06));
    }
  }

  void _paintDustStorm(Canvas canvas, Offset center, double radius) {
    final discPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFD99A58).withOpacity(0.40),
          const Color(0xFF9C6B3E).withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.96));
    canvas.drawCircle(center, radius * 0.96, discPaint);

    _paintAtmosphericLines(
      canvas,
      center,
      radius,
      const Color(0xFFE5B16E).withOpacity(0.64),
    );
  }

  void _paintRainLines(
    Canvas canvas,
    Offset center,
    double radius, {
    required int count,
    required bool heavy,
  }) {
    final paint = Paint()
      ..color = const Color(0xFF79C7FF).withOpacity(heavy ? 0.86 : 0.66)
      ..strokeWidth = math.max(1.0, radius * (heavy ? 0.045 : 0.032))
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final x = center.dx - radius * 0.32 + i * radius * (0.64 / (count - 1));
      final phase = (animationValue + i * 0.14) % 1;
      final y = center.dy + radius * (0.14 + phase * 0.36);
      canvas.drawLine(
        Offset(x + radius * 0.05, y),
        Offset(x - radius * 0.08, y + radius * (heavy ? 0.22 : 0.16)),
        paint,
      );
    }
  }

  void _paintCloudShape(
    Canvas canvas,
    Offset center,
    double size, {
    bool dark = false,
  }) {
    final path = _cloudPath(center, size);
    final bounds = path.getBounds();

    canvas.drawShadow(
      path,
      Colors.black.withOpacity(dark ? 0.34 : 0.20),
      size * 0.08,
      true,
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [
                Color(0xFF9EADC5),
                Color(0xFF65738E),
                Color(0xFF39445B),
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFDDEBFA),
                Color(0xFFAFC3D8),
              ],
      ).createShader(bounds);

    canvas.drawPath(path, fillPaint);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size * 0.018)
      ..color = Colors.white.withOpacity(dark ? 0.18 : 0.34);
    canvas.drawPath(path, highlight);
  }

  Path _cloudPath(Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx - size * 0.50, center.dy + size * 0.12);
    path.cubicTo(
      center.dx - size * 0.50,
      center.dy - size * 0.10,
      center.dx - size * 0.36,
      center.dy - size * 0.22,
      center.dx - size * 0.16,
      center.dy - size * 0.21,
    );
    path.cubicTo(
      center.dx - size * 0.05,
      center.dy - size * 0.43,
      center.dx + size * 0.24,
      center.dy - size * 0.39,
      center.dx + size * 0.31,
      center.dy - size * 0.16,
    );
    path.cubicTo(
      center.dx + size * 0.50,
      center.dy - size * 0.14,
      center.dx + size * 0.58,
      center.dy + size * 0.02,
      center.dx + size * 0.50,
      center.dy + size * 0.18,
    );
    path.cubicTo(
      center.dx + size * 0.38,
      center.dy + size * 0.31,
      center.dx - size * 0.40,
      center.dy + size * 0.31,
      center.dx - size * 0.50,
      center.dy + size * 0.12,
    );
    path.close();
    return path;
  }

  void _paintAtmosphericLines(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1.2, radius * 0.045)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final y = center.dy - radius * 0.20 + i * radius * 0.18;
      final shift = math.sin(animationValue * math.pi * 2 + i) * radius * 0.07;
      canvas.drawLine(
        Offset(center.dx - radius * 0.58 + shift, y),
        Offset(center.dx + radius * 0.58 + shift, y),
        paint..color = color.withOpacity(0.72 - i * 0.10),
      );
    }
  }

  void _paintStar(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );
  }

  bool _isWindOnlyDescription(String desc) {
    final hasWind = desc.contains('WIND') ||
        desc.contains('BREEZE') ||
        desc.contains('BREEZY') ||
        desc.contains('GUST');
    if (!hasWind) return false;

    final hasWeather = desc.contains('RAIN') ||
        desc.contains('DRIZZLE') ||
        desc.contains('SHOWER') ||
        desc.contains('THUNDER') ||
        desc.contains('STORM') ||
        desc.contains('SNOW') ||
        desc.contains('FOG') ||
        desc.contains('MIST') ||
        desc.contains('HAZE') ||
        desc.contains('SMOKE') ||
        desc.contains('DUST') ||
        desc.contains('SAND') ||
        desc.contains('CLOUD') ||
        desc.contains('OVERCAST');

    return !hasWeather;
  }

  @override
  bool shouldRepaint(WeatherIconPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.weatherCode != weatherCode ||
        oldDelegate.isDay != isDay ||
        oldDelegate.customDescription != customDescription;
  }
}
