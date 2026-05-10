import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // General Settings (Units & Logic)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<SettingsProvider>(
                      builder: (context, settings, _) {
                        return Column(
                          children: [
                            // Temperature Unit
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Temperature Unit'),
                              subtitle: const Text('Celsius vs Fahrenheit'),
                              trailing: DropdownButton<String>(
                                value: settings.tempUnit,
                                underline: Container(),
                                items: ['Celsius', 'Fahrenheit']
                                    .map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    settings.setTempUnit(value);
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 24),

                            // Wind Unit
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Wind Speed Unit'),
                              subtitle: const Text('km/h, mph, m/s'),
                              trailing: DropdownButton<String>(
                                value: settings.windUnit,
                                underline: Container(),
                                items:
                                    ['km/h', 'mph', 'm/s'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    settings.setWindUnit(value);
                                  }
                                },
                              ),
                            ),
                            const Divider(height: 24),

                            // Background Refresh
                            SwitchListTile(
                              title: const Text('Background Location Refresh'),
                              subtitle: Text(
                                'Refreshes weather every 30 minutes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                              value: settings.isAutoRefreshEnabled,
                              activeColor: const Color(0xFF667EEA),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) {
                                settings.toggleAutoRefresh(value);
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Theme Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Appearance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              themeProvider.isDarkMode
                                  ? 'Dark Mode Active'
                                  : 'Light Mode Active',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: themeProvider.isDarkMode,
                          activeColor: const Color(0xFF667EEA),
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Permissions Section
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.location_on, color: Colors.blue),
                      ),
                      title: const Text('Location Access'),
                      subtitle: const Text('Manage app permissions'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Open app settings
                        // We need to import 'package:permission_handler/permission_handler.dart';
                        // Since I cannot check imports right now, I'll use a dialog for now or assume package is available
                        // Given user constraints, I will use a simple dialog explaining how to change permissions
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Manage Permissions'),
                            content: const Text(
                                'To change location permissions, please go to your device settings:\n\nSettings > Apps > SkyPulse > Permissions'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // About Section (Updated)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, 'App Version', '1.1.0'),
                    const Divider(),
                    _buildInfoRow(context, 'Developer', 'SkyPulse Pakistan'),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Privacy Policy'),
                            content: const SingleChildScrollView(
                              child: Text(
                                  'SkyPulse Pakistan collects location data to provide real-time weather forecasts and alerts. '
                                  'Your location is only used locally on your device and transmitted to weather APIs for data retrieval. '
                                  'We do not store, sell, or share your personal location data with third parties. '
                                  'Push notifications are opt-in. All data is handled securely under Firebase encryption protocols.'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
