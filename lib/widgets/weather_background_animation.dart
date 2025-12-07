import 'package:flutter/material.dart';
import 'dart:math';

class WeatherBackgroundAnimation extends StatefulWidget {
  final String? weatherCondition;
  final bool isDarkMode;
  final Widget child;

  const WeatherBackgroundAnimation({
    Key? key,
    this.weatherCondition = 'sunny',
    required this.isDarkMode,
    required this.child,
  }) : super(key: key);

  @override
  State<WeatherBackgroundAnimation> createState() =>
      _WeatherBackgroundAnimationState();
}

class _WeatherBackgroundAnimationState extends State<WeatherBackgroundAnimation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _particleControllers;
  final Random _random = Random();
  static const int particleCount = 15;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _particleControllers = List.generate(
      particleCount,
      (_) => AnimationController(
        duration: Duration(seconds: 5 + _random.nextInt(10)),
        vsync: this,
      )..repeat(),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _particleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildBackgroundGradient(),
        ..._buildParticles(),
        widget.child,
      ],
    );
  }

  Widget _buildBackgroundGradient() {
    final condition = widget.weatherCondition?.toLowerCase() ?? 'sunny';

    if (widget.isDarkMode) {
      if (condition.contains('rain') || condition.contains('storm')) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A0E27),
                const Color(0xFF1A1F3A).withOpacity(0.9),
                const Color(0xFF2D1B4E).withOpacity(0.8),
                const Color(0xFF1A1F3A),
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
        );
      } else if (condition.contains('cloud')) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1F3A),
                Color(0xFF2A2E4A),
                Color(0xFF1F2340),
              ],
            ),
          ),
        );
      } else if (condition.contains('snow')) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E2847),
                Color(0xFF2D3A5C),
                Color(0xFF1A2535),
              ],
            ),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A0E27),
                const Color(0xFF1A1F3A),
                const Color(0xFF2D1B4E).withOpacity(0.7),
              ],
            ),
          ),
        );
      }
    } else {
      if (condition.contains('rain') || condition.contains('storm')) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B5998),
                Color(0xFF5B7CAA),
                Color(0xFF6B8EBC),
              ],
            ),
          ),
        );
      } else if (condition.contains('cloud')) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFA8C5E0),
                Color(0xFFD0DEEE),
                Color(0xFFE5EDF7),
              ],
            ),
          ),
        );
      } else if (condition.contains('snow')) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFC5D9F0),
                Color(0xFFE0EBF8),
                Color(0xFFF0F6FC),
              ],
            ),
          ),
        );
      } else {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5DB3E8),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
        );
      }
    }
  }

  List<Widget> _buildParticles() {
    final condition = widget.weatherCondition?.toLowerCase() ?? 'sunny';

    if (condition.contains('rain')) {
      return _buildRaindrops();
    } else if (condition.contains('snow')) {
      return _buildSnowflakes();
    } else if (condition.contains('cloud')) {
      return _buildFloatingClouds();
    } else {
      return _buildSunnyParticles();
    }
  }

  List<Widget> _buildRaindrops() {
    return List.generate(particleCount, (index) {
      final startX = _random.nextDouble();
      final startY = _random.nextDouble();

      return Positioned(
        left: startX * 400,
        top: -50,
        child: AnimatedBuilder(
          animation: _particleControllers[index],
          builder: (context, child) {
            final offset = (startY + _particleControllers[index].value) * 600;
            return Transform.translate(
              offset: Offset(0, offset),
              child: Opacity(
                opacity: 0.6 - (_particleControllers[index].value * 0.3),
                child: CustomPaint(
                  painter: RaindropPainter(isDarkMode: widget.isDarkMode),
                  size: const Size(4, 12),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  List<Widget> _buildSnowflakes() {
    return List.generate(particleCount, (index) {
      final startX = _random.nextDouble();
      final delay = (index * 0.1) % 1.0;

      return Positioned(
        left: startX * 400,
        top: -50,
        child: AnimatedBuilder(
          animation: _particleControllers[index],
          builder: (context, child) {
            final progress = (_particleControllers[index].value + delay) % 1.0;
            final offset = progress * 600;
            final rotation = progress * 4 * pi;

            return Transform.translate(
              offset: Offset(sin(progress * 2 * pi) * 50, offset),
              child: Transform.rotate(
                angle: rotation,
                child: Opacity(
                  opacity: 0.7 - (progress * 0.2),
                  child: CustomPaint(
                    painter: SnowflakePainter(isDarkMode: widget.isDarkMode),
                    size: const Size(20, 20),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  List<Widget> _buildFloatingClouds() {
    return List.generate(5, (index) {
      final startX = (index * 80.0) - 40;
      final yPos = (index * 40.0) % 200;

      return Positioned(
        left: startX,
        top: yPos,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final offset = sin(_animationController.value * 2 * pi) * 30;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: Opacity(
                opacity: 0.3,
                child: CustomPaint(
                  painter: CloudPainter(isDarkMode: widget.isDarkMode),
                  size: const Size(120, 60),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  List<Widget> _buildSunnyParticles() {
    return List.generate(8, (index) {
      final angle = (index / 8) * 2 * pi;
      final radius = 80.0 + (index * 20.0);

      return Positioned(
        right: -radius / 2,
        top: -radius / 2,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final x = cos(angle + _animationController.value * 0.5) * radius;
            final y = sin(angle + _animationController.value * 0.5) * radius;

            return Transform.translate(
              offset: Offset(x, y),
              child: Opacity(
                opacity: 0.1,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isDarkMode
                        ? Colors.yellow.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isDarkMode
                            ? Colors.yellow.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class RaindropPainter extends CustomPainter {
  final bool isDarkMode;
  RaindropPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.blue.withOpacity(0.7) : Colors.blue.shade600
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(RaindropPainter oldDelegate) => false;
}

class SnowflakePainter extends CustomPainter {
  final bool isDarkMode;
  SnowflakePainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.white70 : Colors.blue.shade300
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * pi;
      final endX = center.dx + cos(angle) * radius;
      final endY = center.dy + sin(angle) * radius;

      canvas.drawLine(center, Offset(endX, endY), paint);

      final branchAngle1 = angle + pi / 6;
      final branchX1 = center.dx + cos(branchAngle1) * (radius * 0.6);
      final branchY1 = center.dy + sin(branchAngle1) * (radius * 0.6);
      canvas.drawLine(Offset(endX, endY), Offset(branchX1, branchY1), paint);

      final branchAngle2 = angle - pi / 6;
      final branchX2 = center.dx + cos(branchAngle2) * (radius * 0.6);
      final branchY2 = center.dy + sin(branchAngle2) * (radius * 0.6);
      canvas.drawLine(Offset(endX, endY), Offset(branchX2, branchY2), paint);
    }
  }

  @override
  bool shouldRepaint(SnowflakePainter oldDelegate) => false;
}

class CloudPainter extends CustomPainter {
  final bool isDarkMode;
  CloudPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode ? Colors.white30 : Colors.blue.shade200
      ..style = PaintingStyle.fill;

    final radius = size.width / 6;
    canvas.drawCircle(Offset(radius, size.height / 2), radius, paint);
    canvas.drawCircle(Offset(radius * 2.5, size.height / 2 - radius * 0.3),
        radius * 1.2, paint);
    canvas.drawCircle(Offset(radius * 4, size.height / 2), radius, paint);
    canvas.drawCircle(Offset(radius * 5, size.height / 2 + radius * 0.2),
        radius * 0.9, paint);

    canvas.drawRect(
      Rect.fromLTWH(radius, size.height / 2 - radius * 0.5,
          size.width - 2 * radius, radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(CloudPainter oldDelegate) => false;
}
