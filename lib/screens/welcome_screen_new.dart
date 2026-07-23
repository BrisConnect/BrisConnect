import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/register_selection_screen.dart';

// Theme colours consistent with the rest of the app.
const _backgroundTop = Color(0xFF020326);
const _backgroundMid = Color(0xFF041149);
const _backgroundBottom = Color(0xFF020326);
const _heading = Color(0xFFF5F7FF);
const _subtitle = Color(0xFF9BA9C7);
const _cardDark = Color(0xFF1B2238);
const _accentOrange = Color(0xFFFF7A1A);
const _mutedBlue = Color(0xFF7B8DB8);
const _borderBlue = Color(0xFF2E3650);

class AnimatedWelcomeScreen extends StatefulWidget {
  const AnimatedWelcomeScreen({super.key});

  @override
  State<AnimatedWelcomeScreen> createState() => _AnimatedWelcomeScreenState();
}

class _AnimatedWelcomeScreenState extends State<AnimatedWelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _logoController;
  late AnimationController _cardsController;
  late AudioPlayer _audioPlayer;
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    
    // Netflix-style wave animation for logo
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Logo entrance animation (scale and fade)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      reverseDuration: const Duration(milliseconds: 800),
    );

    // Cards entrance animation
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _audioPlayer = AudioPlayer();
    
    // Start animations sequence
    Future.delayed(const Duration(milliseconds: 300), () {
      _logoController.forward();
      _playWelcomeSound();
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _cardsController.forward();
      }
    });
  }

  Future<void> _playWelcomeSound() async {
    if (_soundPlayed) return;
    _soundPlayed = true;
    
    try {
      await _audioPlayer.setAsset('assets/sounds/welcome.mp3').catchError((_) {
        print('Welcome sound not found, continuing without sound');
        return Duration.zero;
      });
      _audioPlayer.play();
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginSelectionScreen()),
    );
  }

  void _navigateToCreateAccount() {
    // Navigate to registration selection flow.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterSelectionScreen()),
    );
  }

  void _navigateAsGuest() {
    // Guest users browse public content in the visitor portal.
    // The route is defined in lib/main.dart as '/visitor/portal'.
    Navigator.of(context).pushReplacementNamed('/visitor/portal');
  }

  @override
  void dispose() {
    _waveController.dispose();
    _logoController.dispose();
    _cardsController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;
    final horizontalPadding = size.width < 600 ? 24.0 : 48.0;
    final contentWidth = size.width > 600 ? 520.0 : double.infinity;

    return Scaffold(
      backgroundColor: _backgroundTop,
      body: Stack(
        children: [
          // Background with subtle gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_backgroundTop, _backgroundMid, _backgroundBottom],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // BrisConnect+ logo
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _logoController,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/brisconnect_logo.png',
                          width: isSmall ? 200 : 260,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(height: isSmall ? 32 : 44),

                      // Heading + subtitle
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _cardsController,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: Column(
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: isSmall ? 24 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: _heading,
                                  letterSpacing: 0.5,
                                  height: 1.2,
                                ),
                                children: const [
                                  TextSpan(text: "Discover Brisbane's\nLocal Food "),
                                  TextSpan(
                                    text: 'Scene',
                                    style: TextStyle(color: _accentOrange),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Explore local food businesses, promotions and trending places.',
                              style: TextStyle(
                                fontSize: isSmall ? 14 : 16,
                                color: _subtitle,
                                letterSpacing: 0.3,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmall ? 32 : 44),

                      // Explore as Guest (primary orange)
                      _buildPrimaryButton(
                        label: 'Explore as Guest',
                        sublabel: 'Browse businesses and promotions',
                        icon: Icons.explore_outlined,
                        onPressed: _navigateAsGuest,
                      ),

                      const SizedBox(height: 24),

                      // OR divider
                      _buildOrDivider(),

                      const SizedBox(height: 24),

                      // Create Account
                      _buildSecondaryButton(
                        label: 'Create Account',
                        sublabel: 'Join BrisConnect+ today',
                        icon: Icons.person_outline,
                        onPressed: _navigateToCreateAccount,
                      ),

                      const SizedBox(height: 14),

                      // Sign In
                      _buildSecondaryButton(
                        label: 'Sign In',
                        sublabel: 'Welcome back',
                        icon: Icons.login_outlined,
                        onPressed: _navigateToLogin,
                      ),

                      SizedBox(height: isSmall ? 32 : 44),

                      // Feature labels
                      _buildFeatureLabels(),

                      const SizedBox(height: 24),

                      // First Nations acknowledgement
                      _buildAcknowledgement(),

                      const SizedBox(height: 16),
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

  Widget _buildPrimaryButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: _accentOrange.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _accentOrange, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _cardDark,
          foregroundColor: Colors.white,
          side: const BorderSide(color: _borderBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _borderBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _mutedBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _mutedBlue,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _mutedBlue, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Color(0xFF3A4055),
            thickness: 1,
            endIndent: 14,
          ),
        ),
        Text(
          'OR',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _subtitle.withValues(alpha: 0.8),
            letterSpacing: 1.2,
          ),
        ),
        const Expanded(
          child: Divider(
            color: Color(0xFF3A4055),
            thickness: 1,
            indent: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureLabels() {
    final items = [
      (
        icon: Icons.fastfood_outlined,
        color: const Color(0xFFFFA726),
        label: 'Local Food',
        sublabel: 'Find great\nplaces to eat'
      ),
      (
        icon: Icons.local_offer_outlined,
        color: const Color(0xFFEF5350),
        label: 'Promotions',
        sublabel: 'Exclusive deals\n& offers'
      ),
      (
        icon: Icons.location_on_outlined,
        color: const Color(0xFF42A5F5),
        label: 'Nearby',
        sublabel: 'Discover places\nnear you'
      ),
      (
        icon: Icons.trending_up_outlined,
        color: const Color(0xFF66BB6A),
        label: 'Trending',
        sublabel: "See what's\npopular"
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items
          .map(
            (item) => Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: item.color, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _heading,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.sublabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8A9AB8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAcknowledgement() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.favorite, color: Color(0xFFFF7A1A), size: 14),
        const SizedBox(height: 6),
        Text(
          'First Nations Acknowledgement',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8A9AB8).withValues(alpha: 0.85),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'We acknowledge the Traditional Custodians of the land and pay our respects to Elders past and present.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            height: 1.35,
            color: const Color(0xFF8A9AB8).withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// Netflix-style wave overlay painter for logo glow effect
class NetflixWaveOverlayPainter extends CustomPainter {
  final double waveProgress;

  NetflixWaveOverlayPainter({required this.waveProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Create a border glow effect that pulses
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw pulsing border glow
    final glowOpacity = (math.sin(waveProgress * 2 * math.pi) + 1) / 2;
    paint.color = const Color(0xFFFF7A1A).withOpacity(glowOpacity * 0.6);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: size.width - 4,
          height: size.height - 4,
        ),
        const Radius.circular(24),
      ),
      paint,
    );

    // Draw expanding wave rings from edges
    for (int i = 0; i < 2; i++) {
      final delay = i / 2;
      final progress = (waveProgress + delay) % 1.0;
      
      if (progress < 0.8) {
        final opacity = (1.0 - progress) * 0.5;
        paint
          ..strokeWidth = 1.5
          ..color = const Color(0xFF007BFF).withOpacity(opacity);
        
        final expandAmount = progress * 12;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: size.width + (expandAmount * 2),
              height: size.height + (expandAmount * 2),
            ),
            const Radius.circular(28),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(NetflixWaveOverlayPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress;
  }
}

// Original Netflix wave painter (kept for reference)
class NetflixWavePainter extends CustomPainter {
  final double waveProgress;

  NetflixWavePainter({required this.waveProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    const maxRadius = 80.0;

    // Draw multiple expanding waves
    for (int i = 0; i < 3; i++) {
      final waveDelay = (i / 3);
      final animationOffset = (waveProgress + waveDelay) % 1.0;

      // Wave 1: Blue to Orange gradient effect
      if (animationOffset < 0.7) {
        final radius = maxRadius * animationOffset;
        final opacity = (1.0 - animationOffset).clamp(0.0, 1.0);

        paint.color = Color.lerp(
          const Color(0xFF007BFF),
          const Color(0xFFFF7A1A),
          animationOffset,
        )!.withOpacity(0.6 * opacity);

        canvas.drawCircle(center, radius, paint);
      }
    }

    // Draw inner circle with gradient effect
    paint
      ..strokeWidth = 3.0
      ..color = const Color(0xFF007BFF).withOpacity(0.8)
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 40, paint);
  }

  @override
  bool shouldRepaint(NetflixWavePainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress;
  }
}

// Watery logo painter (kept for reference)
class WateryLogoPainter extends CustomPainter {
  final double waveProgress;

  WateryLogoPainter({required this.waveProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF007BFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final wavePaint = Paint()
      ..color = const Color(0xFF007BFF).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    // Draw main circle
    canvas.drawCircle(center, radius, paint);

    // Draw watery wave rings
    final waveCount = 3;
    for (int i = 0; i < waveCount; i++) {
      final waveOffset = (waveProgress + i * 0.33) % 1.0;
      final waveRadius = radius + (waveOffset * radius * 0.4);
      final waveOpacity = (1.0 - waveOffset) * 0.4;

      canvas.drawCircle(
        center,
        waveRadius,
        wavePaint..color = const Color(0xFF007BFF).withOpacity(waveOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(WateryLogoPainter oldDelegate) =>
      oldDelegate.waveProgress != waveProgress;
}
