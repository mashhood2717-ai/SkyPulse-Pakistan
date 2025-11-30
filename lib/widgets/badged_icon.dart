import 'package:flutter/material.dart';

class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onPressed;
  final String? tooltip;

  const BadgedIcon({
    Key? key,
    required this.icon,
    required this.badgeCount,
    required this.onPressed,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
        if (badgeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
