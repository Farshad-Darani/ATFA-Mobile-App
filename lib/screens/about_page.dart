import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';

class AboutPage extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const AboutPage({super.key, required this.onNavigateToTab});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('About ATFA'),
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
            // Company Logo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/Logo.png',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ATFA GILDAR DIAGNOSTICS INC.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🇨🇦', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          'Vancouver, Canada • Est. 2023',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mission Section
            _buildInfoCard(
              context: context,
              icon: Icons.flag_outlined,
              title: 'Our Mission',
              content:
                  'To revolutionize vehicle diagnostics by making professional-grade automotive insights accessible to everyone. We empower drivers with real-time vehicle health monitoring, predictive maintenance, and intelligent diagnostics through cutting-edge technology.',
            ),
            const SizedBox(height: 16),

            // Vision Section
            _buildInfoCard(
              context: context,
              icon: Icons.visibility_outlined,
              title: 'Our Vision',
              content:
                  'To become North America\'s leading automotive diagnostic platform, leveraging artificial intelligence and machine learning to transform how drivers understand, maintain, and protect their vehicles. We\'re building the future of smart vehicle care.',
            ),
            const SizedBox(height: 16),

            // What We Do Section
            _buildInfoCard(
              context: context,
              icon: Icons.engineering_outlined,
              title: 'What We Do',
              content:
                  'ATFA provides complete end-to-end diagnostic solutions including our free mobile app and professional-grade OBD-II diagnostic dongles. Our platform delivers real-time monitoring of critical parameters, error code analysis, and vehicle health scoring. Our upcoming AI-powered diagnostic engine will deliver predictive maintenance insights, personalized recommendations, and intelligent problem detection before issues become critical.',
            ),
            const SizedBox(height: 16),

            // Our Products Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySlate.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppTheme.primarySlate,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Our Products',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProductItem(
                      context: context,
                      icon: Icons.phone_android,
                      title: 'ATFA Diagnostic App',
                      description:
                          'Free download for iOS and Android. Professional vehicle diagnostics at your fingertips.',
                      badge: 'FREE',
                      badgeColor: AppTheme.secondaryBlue,
                    ),
                    const SizedBox(height: 12),
                    _buildProductItem(
                      context: context,
                      icon: Icons.settings_input_composite,
                      title: 'ATFA OBD-II Diagnostic Dongle',
                      description:
                          'Plug-and-play wireless adapter for seamless connection to your vehicle. Compatible with all OBD-II vehicles (1996+).',
                      linkText: 'Available at www.atfagildar.ca',
                      onLinkTap: () => _launchUrl('https://www.atfagildar.ca'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Key Features Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySlate.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.star_outline,
                            color: AppTheme.primarySlate,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Key Features',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      context: context,
                      icon: Icons.speed,
                      title: 'Real-Time Diagnostics',
                      description:
                          'Monitor RPM, speed, temperature, and more parameters live',
                    ),
                    _buildFeatureItem(
                      context: context,
                      icon: Icons.error_outline,
                      title: 'Error Code Analysis',
                      description:
                          'Read and decode DTC error codes with detailed explanations',
                    ),
                    _buildFeatureItem(
                      context: context,
                      icon: Icons.health_and_safety_outlined,
                      title: 'Vehicle Health Score',
                      description:
                          'Comprehensive health assessment at a glance',
                    ),
                    _buildFeatureItem(
                      context: context,
                      icon: Icons.psychology_outlined,
                      title: 'AI-Powered Insights (Coming Soon)',
                      description:
                          'Predictive maintenance and intelligent diagnostics',
                      isComingSoon: true,
                    ),
                    _buildFeatureItem(
                      context: context,
                      icon: Icons.bluetooth,
                      title: 'Bluetooth Connectivity',
                      description: 'Seamless connection to OBD-II devices',
                    ),
                    _buildFeatureItem(
                      context: context,
                      icon: Icons.design_services_outlined,
                      title: 'Intuitive Interface',
                      description:
                          'Professional-grade diagnostics, user-friendly design',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Copyright
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '© 2023-2025 ATFA GILDAR DIAGNOSTICS INC.\nAll rights reserved.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
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

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySlate.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primarySlate, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    bool isComingSoon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isComingSoon ? Colors.orange : AppTheme.primarySlate,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (isComingSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: Text(
                          'Soon',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    String? badge,
    Color? badgeColor,
    String? linkText,
    VoidCallback? onLinkTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primarySlate, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: badgeColor ?? Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: badgeColor ?? Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          if (linkText != null && onLinkTap != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onLinkTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    linkText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primarySlate,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.open_in_new,
                    color: AppTheme.primarySlate,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
