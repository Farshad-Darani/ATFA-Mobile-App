import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'how_it_works_page.dart';
import 'contact_support_page.dart';
import 'legal_page.dart';
import 'auth/sign_in_page.dart';
import 'auth/sign_up_page.dart';

class MorePage extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const MorePage({super.key, required this.onNavigateToTab});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Account section (reactive to auth state) ──────────────────────
            StreamBuilder(
              stream: SupabaseService.client.auth.onAuthStateChange,
              builder: (context, _) => _AccountSection(auth: _auth),
            ),
            const SizedBox(height: 16),

            // ── App logo & title ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Image.asset('assets/images/Logo.png', width: 140, height: 140),
                    const SizedBox(height: 12),
                    Text(
                      'Intelligent Automobile Diagnostic System',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildMenuCard(
              context: context,
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Customize your experience',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SettingsPage(onNavigateToTab: widget.onNavigateToTab))),
            ),
            const SizedBox(height: 16),

            _buildMenuCard(
              context: context,
              icon: Icons.info_outline,
              title: 'About ATFA',
              subtitle: 'Learn more about our company',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AboutPage(onNavigateToTab: widget.onNavigateToTab))),
            ),
            const SizedBox(height: 16),

            _buildMenuCard(
              context: context,
              icon: Icons.help_outline,
              title: 'How It Works',
              subtitle: 'Learn how to use the app',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => HowItWorksPage(onNavigateToTab: widget.onNavigateToTab))),
            ),
            const SizedBox(height: 16),

            _buildMenuCard(
              context: context,
              icon: Icons.contact_support_outlined,
              title: 'Contact & Support',
              subtitle: 'Get help and reach out to us',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ContactSupportPage(onNavigateToTab: widget.onNavigateToTab))),
            ),
            const SizedBox(height: 16),

            _buildMenuCard(
              context: context,
              icon: Icons.gavel,
              title: 'Legal',
              subtitle: 'Privacy policy and terms',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LegalPage(onNavigateToTab: widget.onNavigateToTab))),
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppTheme.primarySlate.withValues(alpha: 0.1),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
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

// ── Account section widget ────────────────────────────────────────────────────
class _AccountSection extends StatefulWidget {
  final AuthService auth;
  const _AccountSection({required this.auth});

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  int _analysesUsed = 0;
  DateTime? _resetDate;
  bool _isPro = false;
  bool _loadingUsage = false;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final user = widget.auth.currentUser;
    if (user == null || widget.auth.isAnonymous) return;
    setState(() => _loadingUsage = true);
    try {
      final row = await SupabaseService.client
          .from('user_plans')
          .select('is_pro, ai_analyses_used, reset_date')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _isPro = row['is_pro'] == true;
          _analysesUsed = (row['ai_analyses_used'] as int?) ?? 0;
          final raw = row['reset_date'] as String?;
          if (raw != null) _resetDate = DateTime.tryParse(raw);
          _loadingUsage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsage = false);
    }
  }

  String _resetLabel() {
    if (_resetDate == null) return '';
    final next = _resetDate!.add(const Duration(days: 30));
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Resets ${months[next.month - 1]} ${next.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isAnon = widget.auth.isAnonymous;
    final isSignedIn = widget.auth.isSignedIn && !isAnon;

    // ── Not signed in (anonymous) ─────────────────────────────────────────────
    if (!isSignedIn) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: AppTheme.accentOrange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('2 free AI analyses · no account needed',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Create a free account to unlock 2 AI analyses every week, saved history, and more.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Create Free Account', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInPage())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primarySlate,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Signed in ─────────────────────────────────────────────────────────────
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isPro
                        ? AppTheme.accentOrange.withValues(alpha: 0.12)
                        : AppTheme.primarySlate.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPro ? Icons.workspace_premium : Icons.person,
                    color: _isPro ? AppTheme.accentOrange : AppTheme.primarySlate,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.auth.currentUser?.email ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _isPro ? 'Pro Plan' : 'Free Plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isPro ? AppTheme.accentOrange : Colors.grey[500],
                          fontWeight: _isPro ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (!_isPro) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('AI Analyses this month', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (_loadingUsage)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Text('$_analysesUsed / 4', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_analysesUsed / 4).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                    _analysesUsed >= 4 ? AppTheme.accentOrange : AppTheme.primaryBlue,
                  ),
                  minHeight: 8,
                ),
              ),
              if (_resetDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_resetLabel(), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {/* TODO: open upgrade flow */},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Upgrade to Pro — \$6.99/mo', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Or \$49.99/year · Unlimited analyses · Cancel anytime',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successGreen, size: 18),
                  const SizedBox(width: 6),
                  const Text('Unlimited AI analyses', style: TextStyle(fontSize: 14)),
                ],
              ),
            ],

            const Divider(height: 28),
            InkWell(
              onTap: () async {
                await widget.auth.signOut();
                await SupabaseService.ensureSession();
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
