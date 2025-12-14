import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'how_it_works_page.dart';
import 'contact_support_page.dart';
import 'legal_page.dart';

class MorePage extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const MorePage({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Logo and Title
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Use actual logo image
                    Image.asset(
                      'assets/images/Logo.png',
                      width: 140,
                      height: 140,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Intelligent Automobile Diagnostic System',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Settings Section
            _buildMenuCard(
              context: context,
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Customize your experience',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SettingsPage(onNavigateToTab: onNavigateToTab),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // About ATFA Section
            _buildMenuCard(
              context: context,
              icon: Icons.info_outline,
              title: 'About ATFA',
              subtitle: 'Learn more about our company',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AboutPage(onNavigateToTab: onNavigateToTab),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // How It Works Section
            _buildMenuCard(
              context: context,
              icon: Icons.help_outline,
              title: 'How It Works',
              subtitle: 'Learn how to use the app',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HowItWorksPage(onNavigateToTab: onNavigateToTab),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Contact & Support Section
            _buildMenuCard(
              context: context,
              icon: Icons.contact_support_outlined,
              title: 'Contact & Support',
              subtitle: 'Get help and reach out to us',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ContactSupportPage(onNavigateToTab: onNavigateToTab),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Legal Section
            _buildMenuCard(
              context: context,
              icon: Icons.gavel,
              title: 'Legal',
              subtitle: 'Privacy policy and terms',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LegalPage(onNavigateToTab: onNavigateToTab),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primarySlate.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primarySlate, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
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
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
