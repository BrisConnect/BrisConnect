import 'package:flutter/material.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/local_signup_screen.dart';
import 'package:brisconnect/screens/visitor_signup_screen.dart';
import 'package:brisconnect/theme/app_palette.dart';

class RegisterSelectionScreen extends StatelessWidget {
  const RegisterSelectionScreen({super.key});

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
                      // Back button
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
                      GestureDetector(
                        onTap: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginSelectionScreen()),
                          (_) => false,
                        ),
                        child: Image.asset('assets/logo.png', height: 140),
                      ),
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
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.charcoal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose how you want to register',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppPalette.mutedText,
                              ),
                            ),
                            const SizedBox(height: 22),

                            _RegisterOptionCard(
                              title: 'Register as Visitor',
                              subtitle:
                                  'Create a visitor account to discover events',
                              icon: Icons.app_registration_rounded,
                              iconColor: AppPalette.ochre,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const VisitorSignUpScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _RegisterOptionCard(
                              title: 'Register as Local',
                              subtitle:
                                  'Create a local account to submit cultural events',
                              icon: Icons.location_city_rounded,
                              iconColor: AppPalette.deepBlue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocalSignUpScreen(),
                                  ),
                                );
                              },
                            ),
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

class _RegisterOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _RegisterOptionCard({
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
            border:
                Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
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
