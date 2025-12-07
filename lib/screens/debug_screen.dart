import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/push_notification_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({Key? key}) : super(key: key);

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String? _fcmToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFCMToken();
  }

  Future<void> _loadFCMToken() async {
    setState(() => _isLoading = true);
    try {
      // Prefer live token, fall back to stored token
      String? token = await PushNotificationService.getFCMToken();
      if (token == null || token.isEmpty) {
        token = await PushNotificationService.getStoredFCMToken();
      }
      setState(() => _fcmToken = token);
    } catch (e) {
      print('Error loading FCM token: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _reinitializeFCM() async {
    print('🔄 [Debug] Reinitializing FCM...');
    await PushNotificationService.reinitialize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ FCM Reinitialized!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FCM Token copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Info'),
        backgroundColor: Colors.black26,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FCM Token Section
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.smartphone,
                                color: Colors.cyan, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'FCM Token',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.cyan,
                                ),
                              )
                            : _fcmToken != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.cyan.withOpacity(0.3),
                                          ),
                                        ),
                                        child: SelectableText(
                                          _fcmToken!,
                                          style: const TextStyle(
                                            color: Colors.cyan,
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            // Use GestureDetector to copy on long press
                                            _copyToClipboard(_fcmToken!);
                                          },
                                          icon: const Icon(Icons.copy),
                                          label: const Text('Copy Token'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.cyan,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _loadFCMToken,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Refresh Token'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                              color: Colors.cyan,
                                              width: 2,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Failed to load FCM token',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                        const SizedBox(height: 12),
                        const Text(
                          'Use this token to test push notifications',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Diagnostics Section
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.analytics,
                                color: Colors.green, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Diagnostics',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow('Messages Received',
                            '${PushNotificationService.getMessageCount()}'),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _reinitializeFCM,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reinitialize FCM'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Instructions Section
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.amber, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'How to Use',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. Copy your FCM token above\n\n'
                          '2. Use it to test push notifications\n\n'
                          '3. Visit Firebase Console → Cloud Messaging\n\n'
                          '4. Send message to:\n'
                          '   • Topic: "all_alerts"\n'
                          '   • OR Device token: paste your token\n\n'
                          '5. Check if notification appears',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Firebase Info Section
                Card(
                  color: Colors.white.withOpacity(0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud, color: Colors.orange, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Firebase Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _InfoRow('Project ID', 'skypulse-pakistan'),
                        _InfoRow('Service', 'Cloud Messaging (FCM)'),
                        _InfoRow('Topics', 'all_alerts, city_alerts'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Test Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speed, color: Colors.lime, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Quick Test',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'To send a test notification:\n\n'
                          '1. Go to Firebase Console\n'
                          '2. Cloud Messaging tab\n'
                          '3. "Send your first message"\n'
                          '4. Fill: Title & Body\n'
                          '5. Target → Topic → "all_alerts"\n'
                          '6. Click "Publish"\n'
                          '7. Check your device',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
