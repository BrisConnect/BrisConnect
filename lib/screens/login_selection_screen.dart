import 'package:flutter/material.dart';
import 'package:brisconnect/screens/admin_login_screen.dart';
import 'package:brisconnect/screens/local_login_screen.dart';
import 'package:brisconnect/screens/visitor_login_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';

class LoginSelectionScreen extends StatefulWidget {
  const LoginSelectionScreen({super.key});

  @override
  State<LoginSelectionScreen> createState() => _LoginSelectionScreenState();
}

class _LoginSelectionScreenState extends State<LoginSelectionScreen> {
  int _adminTapCount = 0;
  bool _showAdminLogin = false;

  void _onTitleTap() {
    _adminTapCount++;
    if (_adminTapCount >= 5 && !_showAdminLogin) {
      setState(() => _showAdminLogin = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin login unlocked'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AboriginalDotArtBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      // Back button row
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Logo
                      Image.asset('assets/logo.png', height: 120),
                      const SizedBox(height: 20),

                      // Card
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: AppPalette.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: AppPalette.cardShadow,
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _onTitleTap,
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.charcoal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose your account type',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppPalette.mutedText,
                              ),
                            ),
                            const SizedBox(height: 22),

                            _LoginOptionCard(
                              title: 'Visitor Login',
                              subtitle:
                                  'Browse events, culture, and local experiences',
                              icon: Icons.travel_explore_rounded,
                              iconColor: AppPalette.ochre,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const VisitorLoginScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _LoginOptionCard(
                              title: 'Local Login',
                              subtitle:
                                  'Manage local submissions and community events',
                              icon: Icons.location_city_rounded,
                              iconColor: AppPalette.deepBlue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocalLoginScreen(),
                                  ),
                                );
                              },
                            ),
                            if (_showAdminLogin) ...[
                              const SizedBox(height: 12),
                              _LoginOptionCard(
                                title: 'Admin Login',
                                subtitle: 'Access review and management tools',
                                icon: Icons.admin_panel_settings_rounded,
                                iconColor: AppPalette.gold,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminLoginScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _LoginOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppPalette.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.charcoal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppPalette.ochre.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppPalette.ochre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}