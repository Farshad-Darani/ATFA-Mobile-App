import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class HowItWorksPage extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const HowItWorksPage({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How It Works'),
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
            // Introduction
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.primarySlate,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Getting Started with ATFA',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow these simple steps to start diagnosing your vehicle',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Step 1: Get Your ATFA Dongle
            _buildStepCard(
              context: context,
              stepNumber: '1',
              title: 'Get Your ATFA Dongle',
              description:
                  'Purchase the ATFA OBD-II diagnostic dongle from our website. This wireless adapter connects your vehicle to the app.',
              imagePath: 'assets/images/OBDII.png',
              imageHeight: 180,
            ),
            const SizedBox(height: 16),

            // Step 2: Locate Your OBD-II Port
            _buildStepCard(
              context: context,
              stepNumber: '2',
              title: 'Locate Your OBD-II Port',
              description:
                  'Find the OBD-II port in your vehicle. It\'s typically located under the dashboard on the driver\'s side, near the steering column. All vehicles manufactured after 1996 have this port.',
            ),
            const SizedBox(height: 16),

            // Step 3: Connect the Dongle
            _buildStepCard(
              context: context,
              stepNumber: '3',
              title: 'Connect the Dongle',
              description:
                  'Plug the ATFA dongle into your vehicle\'s OBD-II port with the ignition on or engine running. The dongle will power up automatically.',
            ),
            const SizedBox(height: 16),

            // Step 4: Pair via Bluetooth
            _buildStepCard(
              context: context,
              stepNumber: '4',
              title: 'Pair via Bluetooth',
              description:
                  'Open the ATFA app and go to the Connect tab. Scan for devices and select your ATFA dongle (typically named "OBDII"). The app will establish a secure Bluetooth connection.',
            ),
            const SizedBox(height: 16),

            // Step 5: Start Diagnostics
            _buildStepCard(
              context: context,
              stepNumber: '5',
              title: 'Start Diagnostics',
              description:
                  'Once connected, navigate to the Live Data tab. Press "Start Diagnostics" to begin monitoring your vehicle\'s real-time parameters and health status.',
            ),
            const SizedBox(height: 24),

            // Understanding Your Data Section
            _buildSectionHeader(
              context: context,
              icon: Icons.analytics_outlined,
              title: 'Understanding Your Data',
            ),
            const SizedBox(height: 12),

            // Parameters Explained
            _buildInfoCard(
              context: context,
              title: 'Diagnostic Parameters',
              items: [
                _InfoItem(
                  icon: Icons.speed,
                  label: 'RPM (Revolutions Per Minute)',
                  description:
                      'Engine speed. Normal idle: 600-1000 RPM. Higher when accelerating.',
                ),
                _InfoItem(
                  icon: Icons.directions_car,
                  label: 'Speed',
                  description: 'Current vehicle speed in km/h or mph.',
                ),
                _InfoItem(
                  icon: Icons.thermostat,
                  label: 'Coolant Temperature',
                  description:
                      'Engine temperature. Normal: 85-105°C. High temps may indicate overheating.',
                ),
                _InfoItem(
                  icon: Icons.tune,
                  label: 'Throttle Position',
                  description:
                      'How far the gas pedal is pressed. 0% = idle, 100% = full throttle.',
                ),
                _InfoItem(
                  icon: Icons.battery_charging_full,
                  label: 'Battery Voltage',
                  description:
                      'Electrical system health. Normal: 12-14V (engine off), 13.5-14.5V (running).',
                ),
                _InfoItem(
                  icon: Icons.fitness_center,
                  label: 'Engine Load',
                  description:
                      'How hard the engine is working. Higher when accelerating or climbing.',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error Codes Explained
            _buildInfoCard(
              context: context,
              title: 'Error Codes (DTCs)',
              items: [
                _InfoItem(
                  icon: Icons.error_outline,
                  label: 'What are DTCs?',
                  description:
                      'Diagnostic Trouble Codes are generated when your vehicle detects a problem. They help identify specific issues.',
                ),
                _InfoItem(
                  icon: Icons.code,
                  label: 'Code Format',
                  description:
                      'P = Powertrain, C = Chassis, B = Body, U = Network. Followed by 4 digits (e.g., P0300 = Engine Misfire).',
                ),
                _InfoItem(
                  icon: Icons.psychology_outlined,
                  label: 'AI-Powered Solutions',
                  description:
                      'Our upcoming AI engine will automatically detect problems from error codes and provide intelligent recommendations, step-by-step solutions, and preventive maintenance advice tailored to your specific vehicle issue.',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle Health Score
            _buildInfoCard(
              context: context,
              title: 'Vehicle Health Score',
              items: [
                _InfoItem(
                  icon: Icons.check_circle,
                  label: '80-100%: Excellent',
                  description:
                      'Your vehicle is in great condition. All parameters are normal.',
                  color: const Color(0xFF2196F3),
                ),
                _InfoItem(
                  icon: Icons.warning,
                  label: '60-79%: Warning',
                  description:
                      'Some parameters need attention. Check warnings for details.',
                  color: Colors.orange,
                ),
                _InfoItem(
                  icon: Icons.error,
                  label: 'Below 60%: Critical',
                  description:
                      'Immediate attention required. Critical issues detected.',
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Troubleshooting Section
            _buildSectionHeader(
              context: context,
              icon: Icons.build_outlined,
              title: 'Troubleshooting',
            ),
            const SizedBox(height: 12),

            _buildTroubleshootCard(
              context: context,
              problem: 'Can\'t find the dongle',
              solutions: [
                'Make sure the dongle is plugged in and vehicle ignition is on',
                'Check that Bluetooth is enabled on your phone',
                'Try turning Bluetooth off and on again',
                'Ensure no other device is connected to the dongle',
              ],
            ),
            const SizedBox(height: 12),

            _buildTroubleshootCard(
              context: context,
              problem: 'Connection keeps dropping',
              solutions: [
                'Ensure the dongle is fully inserted into the OBD-II port',
                'Keep your phone within 10 meters of the vehicle',
                'Close other apps that might use Bluetooth',
                'Try disconnecting and reconnecting',
              ],
            ),
            const SizedBox(height: 12),

            _buildTroubleshootCard(
              context: context,
              problem: 'No data showing',
              solutions: [
                'Verify the vehicle engine is running',
                'Check that the dongle LED is blinking (indicates activity)',
                'Try pressing "Start Diagnostics" again',
                'Disconnect and reconnect to reset the connection',
              ],
            ),
            const SizedBox(height: 24),

            // Need More Help Card
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : AppTheme.primarySlate.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.contact_support,
                      size: 40,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.primarySlate,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Need More Help?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contact our support team at support@atfagildar.ca\nOr visit www.atfagildar.ca for more resources',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // More tab is selected
        onTap: (index) {
          Navigator.popUntil(context, (route) => route.isFirst);
          onNavigateToTab(index);
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

  Widget _buildStepCard({
    required BuildContext context,
    required String stepNumber,
    required String title,
    required String description,
    String? imagePath,
    double? imageHeight,
    IconData? icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      stepNumber,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            if (imagePath != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    imagePath,
                    height: imageHeight ?? 150,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
            if (icon != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Icon(
                  icon,
                  size: 64,
                  color: AppTheme.primarySlate.withOpacity(0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.1)
                : AppTheme.primarySlate.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : AppTheme.primarySlate,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required List<_InfoItem> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _buildInfoItem(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, _InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            color:
                item.color ??
                (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppTheme.primarySlate),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootCard({
    required BuildContext context,
    required String problem,
    required List<String> solutions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.primarySlate,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...solutions.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String description;
  final Color? color;

  _InfoItem({
    required this.icon,
    required this.label,
    required this.description,
    this.color,
  });
}
