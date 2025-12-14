import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class SettingsPage extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const SettingsPage({super.key, required this.onNavigateToTab});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state variables
  bool _useCelsius = true; // Temperature unit
  bool _useKmh = true; // Speed unit
  int _refreshRate = 1; // Refresh rate in seconds (1-5)
  bool _showNotifications = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Units Section
            _buildSectionCard(
              title: 'Units',
              children: [
                _buildSwitchTile(
                  title: 'Temperature',
                  subtitle: _useCelsius ? 'Celsius (°C)' : 'Fahrenheit (°F)',
                  icon: Icons.thermostat,
                  value: _useCelsius,
                  onChanged: (value) {
                    setState(() {
                      _useCelsius = value;
                    });
                  },
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  title: 'Speed',
                  subtitle: _useKmh ? 'Kilometers (km/h)' : 'Miles (mph)',
                  icon: Icons.speed,
                  value: _useKmh,
                  onChanged: (value) {
                    setState(() {
                      _useKmh = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Data Section
            _buildSectionCard(
              title: 'Data',
              children: [
                _buildSliderTile(
                  title: 'Refresh Rate',
                  subtitle:
                      '$_refreshRate second${_refreshRate > 1 ? 's' : ''}',
                  icon: Icons.refresh,
                  value: _refreshRate.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (value) {
                    setState(() {
                      _refreshRate = value.toInt();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notifications Section
            _buildSectionCard(
              title: 'Notifications',
              children: [
                _buildSwitchTile(
                  title: 'Enable Notifications',
                  subtitle: 'Get alerts for critical issues',
                  icon: Icons.notifications,
                  value: _showNotifications,
                  onChanged: (value) {
                    setState(() {
                      _showNotifications = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Appearance Section
            _buildSectionCard(
              title: 'Appearance',
              children: [
                _buildSwitchTile(
                  title: 'Dark Mode',
                  subtitle: _darkMode
                      ? 'Dark theme enabled'
                      : 'Light theme enabled',
                  icon: Icons.dark_mode,
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // More tab is selected
        onTap: (index) {
          Navigator.popUntil(context, (route) => route.isFirst);
          widget.onNavigateToTab(index);
        },
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_searching),
            activeIcon: Icon(Icons.bluetooth_connected),
            label: 'Connect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Live Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz_outlined),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primarySlate.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primarySlate, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primarySlate.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primarySlate, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(0xFF2196F3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
