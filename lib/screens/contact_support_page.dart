import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';

class ContactSupportPage extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const ContactSupportPage({super.key, required this.onNavigateToTab});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  Future<void> _launchEmail(String email, {String? subject}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: subject != null ? 'subject=$subject' : null,
    );
    if (!await launchUrl(emailUri)) {
      throw Exception('Could not launch email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact & Support'),
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
            // Introduction Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.contact_support,
                      size: 48,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.primarySlate,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We\'re Here to Help',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Have questions or need assistance? Reach out to us through any of the channels below.',
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

            // Website Section
            _buildContactCard(
              context: context,
              icon: Icons.language,
              title: 'Visit Our Website',
              subtitle: 'www.atfagildar.ca',
              description: 'Browse our products, resources, and latest updates',
              onTap: () => _launchUrl('https://www.atfagildar.ca'),
            ),
            const SizedBox(height: 12),

            // Support Email Section
            _buildContactCard(
              context: context,
              icon: Icons.email_outlined,
              title: 'Support Email',
              subtitle: 'support@atfagildar.ca',
              description: 'Technical support and troubleshooting assistance',
              onTap: () => _launchEmail(
                'support@atfagildar.ca',
                subject: 'Support Request',
              ),
            ),
            const SizedBox(height: 12),

            // General Inquiries Email Section
            _buildContactCard(
              context: context,
              icon: Icons.mail_outline,
              title: 'General Inquiries',
              subtitle: 'info@atfagildar.ca',
              description:
                  'Questions about products, partnerships, or general information',
              onTap: () => _launchEmail('info@atfagildar.ca'),
            ),
            const SizedBox(height: 24),

            // Help Resources Section
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.1)
                                : AppTheme.primarySlate.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.help_center_outlined,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : AppTheme.primarySlate,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Help Resources',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildHelpItem(
                      context: context,
                      icon: Icons.quiz_outlined,
                      title: 'Frequently Asked Questions',
                      description:
                          'Find quick answers to common questions about the app, dongle setup, and diagnostics.',
                    ),
                    const Divider(height: 24),
                    _buildHelpItem(
                      context: context,
                      icon: Icons.book_outlined,
                      title: 'User Guide',
                      description:
                          'Step-by-step instructions for getting started and using all features.',
                    ),
                    const Divider(height: 24),
                    _buildHelpItem(
                      context: context,
                      icon: Icons.code_outlined,
                      title: 'Error Code Reference',
                      description:
                          'Lookup diagnostic trouble codes (DTCs) and understand what they mean.',
                    ),
                    const Divider(height: 24),
                    _buildHelpItem(
                      context: context,
                      icon: Icons.build_outlined,
                      title: 'Troubleshooting',
                      description:
                          'Solutions for connection issues, data problems, and common errors.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Location Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.primarySlate,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ATFA GILDAR DIAGNOSTICS INC.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vancouver, British Columbia\nCanada',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
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

  Widget _buildContactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
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
                  color: AppTheme.secondaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.secondaryBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF2196F3),
                        fontWeight: FontWeight.w500,
                      ),
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
              Icon(Icons.open_in_new, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : AppTheme.primarySlate,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
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
    );
  }
}
