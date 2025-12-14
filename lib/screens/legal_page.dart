import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class LegalPage extends StatelessWidget {
  final Function(int) onNavigateToTab;

  const LegalPage({super.key, required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal'),
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
                      Icons.gavel,
                      size: 48,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.primarySlate,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Legal Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your privacy and rights matter to us. Review our policies below.',
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

            // Privacy Policy Section
            _buildLegalCard(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Terms of Service Section
            _buildLegalCard(
              context: context,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Usage terms and conditions',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServicePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Open Source Licenses Section
            _buildLegalCard(
              context: context,
              icon: Icons.code,
              title: 'Open Source Licenses',
              subtitle: 'Third-party software licenses',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LicensePage(
                      applicationName: 'ATFA',
                      applicationVersion: '1.0.0',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Copyright Notice
            Card(
              color: const Color(0xFF2196F3).withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '© 2023-2025',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ATFA GILDAR DIAGNOSTICS INC.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All rights reserved.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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

  Widget _buildLegalCard({
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : AppTheme.primarySlate.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.primarySlate,
                  size: 28,
                ),
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

// Privacy Policy Page
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context: context,
              title: 'Effective Date',
              content: 'December 14, 2025',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Introduction',
              content:
                  'ATFA GILDAR DIAGNOSTICS INC. ("ATFA," "we," "us," or "our") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our ATFA mobile application (the "App").',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Information We Collect',
              content:
                  'Device Information: We may collect information about your mobile device, including device type, operating system, and unique device identifiers.\n\nVehicle Diagnostic Data: The App collects real-time diagnostic data from your vehicle via the OBD-II dongle, including but not limited to RPM, speed, engine temperature, throttle position, battery voltage, error codes, and other performance metrics.\n\nUsage Data: We may collect information about how you interact with the App, including features used, session duration, and app performance data.\n\nLocation Data: With your permission, we may collect location information to provide location-based services.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'How We Use Your Information',
              content:
                  'We use the information we collect to:\n\n• Provide and maintain the App\'s functionality\n• Display real-time vehicle diagnostics and health information\n• Analyze and improve App performance\n• Provide customer support\n• Detect and prevent technical issues\n• Comply with legal obligations',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Data Storage and Processing',
              content:
                  'Vehicle diagnostic data is processed locally on your device. We do not automatically transmit or store your vehicle data on our servers unless you explicitly choose to share diagnostic reports with our support team.\n\nAny data shared with us for support purposes is stored securely and only accessible to authorized personnel.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Information Sharing',
              content:
                  'We do not sell, trade, or rent your personal information to third parties. We may share information only in the following circumstances:\n\n• With your explicit consent\n• To comply with legal obligations or respond to lawful requests\n• To protect our rights, privacy, safety, or property\n• With service providers who assist us in operating the App (under strict confidentiality agreements)',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Data Security',
              content:
                  'We implement appropriate technical and organizational measures to protect your information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Your Rights',
              content:
                  'You have the right to:\n\n• Access your personal information\n• Request correction of inaccurate data\n• Request deletion of your data\n• Withdraw consent for data processing\n• Object to certain data processing activities',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Children\'s Privacy',
              content:
                  'The App is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided us with personal information, please contact us.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Changes to This Policy',
              content:
                  'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the App and updating the "Effective Date" at the top.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Contact Us',
              content:
                  'If you have questions about this Privacy Policy, please contact us:\n\nEmail: info@atfagildar.ca\nWebsite: www.atfagildar.ca\n\nATFA GILDAR DIAGNOSTICS INC.\nVancouver, British Columbia, Canada',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String content,
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
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// Terms of Service Page
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context: context,
              title: 'Effective Date',
              content: 'December 14, 2025',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Acceptance of Terms',
              content:
                  'By downloading, installing, or using the ATFA mobile application (the "App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.\n\nATFA GILDAR DIAGNOSTICS INC. ("ATFA," "we," "us," or "our") reserves the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the modified Terms.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'License to Use',
              content:
                  'We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes in accordance with these Terms. You may not:\n\n• Modify, reverse engineer, or decompile the App\n• Use the App for any illegal or unauthorized purpose\n• Interfere with or disrupt the App\'s functionality\n• Attempt to gain unauthorized access to any systems or data',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Hardware Requirements',
              content:
                  'The App requires a compatible OBD-II Bluetooth dongle to function properly. ATFA sells branded dongles, but the App may work with other OBD-II devices. You are responsible for ensuring compatibility and proper installation of any hardware used with the App.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Vehicle Compatibility',
              content:
                  'The App is designed for use with OBD-II compliant vehicles (typically manufactured after 1996). Compatibility may vary by vehicle make, model, and year. Some features may not be available for all vehicles.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Diagnostic Information',
              content:
                  'The App provides diagnostic information for informational purposes only. It is not a substitute for professional automotive diagnosis and repair. You should:\n\n• Consult qualified automotive professionals for critical vehicle issues\n• Not rely solely on the App for safety-critical decisions\n• Understand that diagnostic codes require professional interpretation\n• Use the App as a supplementary tool, not a replacement for professional service',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Limitation of Liability',
              content:
                  'TO THE MAXIMUM EXTENT PERMITTED BY LAW, ATFA SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES RESULTING FROM:\n\n• Your use or inability to use the App\n• Any unauthorized access to or use of our servers\n• Any errors or omissions in diagnostic information\n• Vehicle damage or malfunction\n• Any other matter relating to the App',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Disclaimer of Warranties',
              content:
                  'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.\n\nWe do not warrant that the App will be uninterrupted, error-free, or free of viruses or other harmful components.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'User Responsibilities',
              content:
                  'You are responsible for:\n\n• Maintaining the security of your device\n• Ensuring safe use of the App while operating a vehicle\n• Complying with all applicable laws and regulations\n• Proper installation and use of OBD-II hardware\n• Any consequences of relying on diagnostic information',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Intellectual Property',
              content:
                  'All content, features, and functionality of the App, including but not limited to text, graphics, logos, icons, images, and software, are the exclusive property of ATFA or its licensors and are protected by copyright, trademark, and other intellectual property laws.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Termination',
              content:
                  'We reserve the right to terminate or suspend your access to the App at any time, without notice, for any reason, including violation of these Terms.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Governing Law',
              content:
                  'These Terms shall be governed by and construed in accordance with the laws of British Columbia, Canada, without regard to its conflict of law provisions.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'Contact Information',
              content:
                  'For questions about these Terms, contact us:\n\nEmail: info@atfagildar.ca\nWebsite: www.atfagildar.ca\n\nATFA GILDAR DIAGNOSTICS INC.\nVancouver, British Columbia, Canada',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required String content,
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
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
