import 'package:flutter/material.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/register_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _background = Color(0xFFF7F4ED);
  static const Color _ochre = Color(0xFFC65D2E);
  static const Color _gold = Color(0xFFD4A017);
  static const Color _deepBlue = Color(0xFF1E3A5F);
  static const Color _charcoal = Color(0xFF2B2B2B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              top: -90,
              right: -80,
              child: _DecorCircle(
                size: 220,
                color: Color(0x33D4A017),
              ),
            ),
            const Positioned(
              top: 170,
              left: -55,
              child: _DecorCircle(
                size: 130,
                color: Color(0x33C65D2E),
              ),
            ),
            const Positioned(
              bottom: -70,
              right: -30,
              child: _DecorCircle(
                size: 160,
                color: Color(0x221E3A5F),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity)),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        decoration: BoxDecoration(
                          color: const Color(0xF9FFFDF8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE4D8C4)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 30,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1) Decorative top section/logo
                            Container(
                              width: 102,
                              height: 102,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFF6DF), Color(0xFFF5E2D6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFE1C9A2),
                                  width: 1.2,
                                ),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: const [
                                _ThemeChip(icon: Icons.celebration_rounded, label: 'Events'),
                                _ThemeChip(icon: Icons.museum_rounded, label: 'Culture'),
                                _ThemeChip(icon: Icons.groups_rounded, label: 'Community'),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 2) App title
                            const Text(
                              'BrisConnect',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: _charcoal,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 3) Slogan
                            const Text(
                              'Experience Brisbane Like a Local',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _deepBlue,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 4) Main description
                            const Text(
                              'Find things to do in Brisbane and explore events, culture, and local experiences as the city prepares for the 2032 Olympic Games.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15.5,
                                height: 1.58,
                                color: _charcoal,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 5) Acknowledgement text
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8EA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE8D3AA)),
                              ),
                              child: const Text(
                              'We acknowledge the First Nations peoples, the Traditional Custodians of this land, and honour their culture and connection to community.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: Color(0xFF6C5A43),
                              ),
                            ),
                            ),
                            const SizedBox(height: 12),

                            // 6) Small trust line
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: _gold,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                              'Safe and trusted for visitors and locals.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _deepBlue,
                              ),
                            ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),

                            // 7) Log In button (primary)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginSelectionScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ochre,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: const Color(0x33C65D2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: const Text('Log In'),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 8) Create Account button (secondary)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterSelectionScreen(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _deepBlue,
                                  side: const BorderSide(
                                    color: _gold,
                                    width: 1.5,
                                  ),
                                  backgroundColor: const Color(0xFFFFFBF1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: const Text('Create Account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ThemeChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7D5B1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: WelcomeScreen._ochre),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WelcomeScreen._deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}
