import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:brisconnect/screens/login_selection_screen.dart';
import 'package:brisconnect/screens/register_selection_screen.dart';

class AnimatedWelcomeScreen extends StatefulWidget {
  const AnimatedWelcomeScreen({Key? key}) : super(key: key);

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

  void _navigateToGetStarted() {
    // Navigate to registration selection flow.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegisterSelectionScreen()),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFF020326),
      body: Stack(
        children: [
          // Background with subtle gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF020326),
                  const Color(0xFF041149),
                  const Color(0xFF020326),
                ],
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Netflix-style animated logo entrance
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
                    ),
                    child: Image.asset(
                      'assets/images/brisconnect_logo.png',
                      width: 260,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Welcome text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(parent: _cardsController, curve: Curves.easeOut),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Welcome to BrisConnect+',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF5F7FF),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Discover events and attractions',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9BA9C7),
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Two action cards
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-0.5, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: _cardsController, curve: Curves.easeOut),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildActionCard(
                        title: 'Get Started',
                        subtitle: 'Create account & explore',
                        icon: Icons.rocket_launch,
                        onTap: _navigateToGetStarted,
                        isPrimary: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.5, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: _cardsController, curve: Curves.easeOut),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildActionCard(
                        title: 'Sign In',
                        subtitle: 'Use existing account',
                        icon: Icons.login,
                        onTap: _navigateToLogin,
                        isPrimary: false,
                      ),
                    ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'First Nations Acknowledgement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5ECFF),
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'We acknowledge the Traditional Custodians of the land and pay our respects to Elders past and present.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: Color(0xFFB8C7E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
              gradient: isPrimary
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF0B3E82).withOpacity(0.86),
                        const Color(0xFF0A2F67).withOpacity(0.86),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        const Color(0xFF0C1D3A).withOpacity(0.92),
                        const Color(0xFF10264A).withOpacity(0.92),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            border: Border.all(
              color: isPrimary
                    ? const Color(0xFF3BA2E8).withOpacity(0.45)
                    : const Color(0xFF3BA2E8).withOpacity(0.20),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                      ? const Color(0xFF0E4A95).withOpacity(0.32)
                    : Colors.transparent,
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrimary
                      ? const Color(0xFFFF7A1A).withOpacity(0.8)
                      : const Color(0xFF3BA2E8).withOpacity(0.26),
                ),
                child: Icon(
                  icon,
                  color: isPrimary ? Colors.white : const Color(0xFF8DD4FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF5F7FF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPrimary
                            ? const Color(0xFFF5F7FF).withOpacity(0.7)
                            : const Color(0xFF9BA9C7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isPrimary
                    ? Colors.white
                    : const Color(0xFF9BA9C7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
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
