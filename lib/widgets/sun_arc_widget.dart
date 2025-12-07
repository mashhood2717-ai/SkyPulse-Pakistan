import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class SunArcWidget extends StatelessWidget {
  final int sunrise;
  final int sunset;

  const SunArcWidget({
    Key? key,
    required this.sunrise,
    required this.sunset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sunriseTime = DateTime.fromMillisecondsSinceEpoch(sunrise * 1000);
    final sunsetTime = DateTime.fromMillisecondsSinceEpoch(sunset * 1000);

    // Calculate progress (0 to 1)
    double progress = 0.0;
    if (now >= sunrise && now <= sunset) {
      progress = (now - sunrise) / (sunset - sunrise);
    } else if (now > sunset) {
      progress = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Left side: Sunrise and Sunset times
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sunrise
              Row(
                children: [
                  const Icon(
                    Icons.wb_twilight,
                    color: Color(0xFFFFA726),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sunrise',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.jm().format(sunriseTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sunset
              Row(
                children: [
                  const Icon(
                    Icons.wb_twilight,
                    color: Color(0xFFEF5350),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sunset',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.jm().format(sunsetTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 20),

          // Right side: Sun arc
          Expanded(
            child: SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: SunArcPainter(progress: progress),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SunArcPainter extends CustomPainter {
  final double progress;

  SunArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width * 0.45;

    // Draw background arc (track)
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      backgroundPaint,
    );

    // Draw progress arc (filled portion)
    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFA726), // Orange
            Color(0xFFFFD54F), // Yellow
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        progressPaint,
      );
    }

    // Calculate sun position
    final angle = math.pi + (math.pi * progress);
    final sunX = center.dx + radius * math.cos(angle);
    final sunY = center.dy + radius * math.sin(angle);
    final sunPosition = Offset(sunX, sunY);

    // Draw sun glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFA726).withOpacity(0.4),
          const Color(0xFFFFA726).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: sunPosition, radius: 30));

    canvas.drawCircle(sunPosition, 30, glowPaint);

    // Draw sun
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFD54F),
          Color(0xFFFFA726),
        ],
      ).createShader(Rect.fromCircle(center: sunPosition, radius: 16));

    canvas.drawCircle(sunPosition, 16, sunPaint);

    // Draw sun border
    final sunBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(sunPosition, 16, sunBorderPaint);

    // Draw sun icon
    final textSpan = TextSpan(
      text: _getSunEmoji(progress),
      style: const TextStyle(fontSize: 20),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(sunX - textPainter.width / 2, sunY - textPainter.height / 2),
    );
  }

  String _getSunEmoji(double progress) {
    if (progress <= 0) return '🌙';
    if (progress >= 1) return '🌙';
    if (progress < 0.2) return '🌅';
    if (progress > 0.8) return '🌇';
    return '☀️';
  }

  @override
  bool shouldRepaint(SunArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
