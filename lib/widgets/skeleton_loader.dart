import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    Key? key,
    this.width = double.infinity,
    this.height = 100,
    this.margin = const EdgeInsets.all(0),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) : super(key: key);

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
        return Container(
          margin: widget.margin,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.withOpacity(0.3),
                Colors.grey.withOpacity(0.15),
                Colors.grey.withOpacity(0.3),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card for weather loading state
class WeatherSkeletonCard extends StatelessWidget {
  const WeatherSkeletonCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.2),
            Colors.purple.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location skeleton
          SkeletonLoader(
            width: 150,
            height: 24,
            margin: const EdgeInsets.only(bottom: 12),
            borderRadius: BorderRadius.circular(12),
          ),
          // Temperature skeleton
          SkeletonLoader(
            width: 100,
            height: 48,
            margin: const EdgeInsets.only(bottom: 16),
            borderRadius: BorderRadius.circular(12),
          ),
          // Condition skeleton
          SkeletonLoader(
            width: 200,
            height: 18,
            margin: const EdgeInsets.only(bottom: 12),
            borderRadius: BorderRadius.circular(12),
          ),
          // Details skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader(
                width: 80,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
              SkeletonLoader(
                width: 80,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
              SkeletonLoader(
                width: 80,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
