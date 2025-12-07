import 'package:flutter/material.dart';
import '../screens/alert_detail_screen.dart';

/// Clickable Alert Banner Widget
class AlertBanner extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback? onDismiss;

  const AlertBanner({
    Key? key,
    required this.alert,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] ?? 'medium';
    final title = alert['title'] ?? 'Alert';
    final message = alert['message'] ?? '';
    final zoneName = alert['zone_name'] ?? 'Area';

    return GestureDetector(
      onTap: () {
        // Open alert detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertDetailScreen(alert: alert),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getSeverityGradient(severity),
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _getSeverityColor(severity).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _getSeverityColor(severity).withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Severity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getSeverityLabel(severity),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zone Name
                    Text(
                      zoneName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Message
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Close button
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.6),
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFF5252);
      case 'high':
        return const Color(0xFFFF9800);
      case 'medium':
        return const Color(0xFFFFC107);
      case 'low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF2196F3);
    }
  }

  List<Color> _getSeverityGradient(String severity) {
    final baseColor = _getSeverityColor(severity);
    return [
      baseColor.withOpacity(0.2),
      baseColor.withOpacity(0.1),
    ];
  }

  String _getSeverityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'CRITICAL';
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MEDIUM';
      case 'low':
        return 'LOW';
      default:
        return 'INFO';
    }
  }
}

/// Alert List Widget - Shows all active alerts
class AlertList extends StatefulWidget {
  final List<Map<String, dynamic>> alerts;

  const AlertList({
    Key? key,
    required this.alerts,
  }) : super(key: key);

  @override
  State<AlertList> createState() => _AlertListState();
}

class _AlertListState extends State<AlertList> {
  late Set<int> dismissedIndices;

  @override
  void initState() {
    super.initState();
    dismissedIndices = {};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleAlerts = widget.alerts
        .asMap()
        .entries
        .where((e) => !dismissedIndices.contains(e.key))
        .map((e) => e.value)
        .toList();

    if (visibleAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: visibleAlerts.map((alert) {
        final index = widget.alerts.indexOf(alert);
        return AlertBanner(
          alert: alert,
          onDismiss: () {
            setState(() {
              dismissedIndices.add(index);
            });
          },
        );
      }).toList(),
    );
  }
}

/// Alert Counter Badge
class AlertBadge extends StatelessWidget {
  final int count;

  const AlertBadge({
    Key? key,
    required this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '🚨 $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
